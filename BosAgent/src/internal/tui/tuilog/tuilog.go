// Package tuilog — herramienta de logging de seguimiento del TUI SBOS.
//
// BACKEND: Ubuntu journald (vía syslog).
// Los eventos del TUI se escriben en journald con SYSLOG_IDENTIFIER=bos-tui.
// La herramienta también puede leer cualquier otra unidad systemd para el viewer.
//
// Consultar los logs desde la terminal:
//
//	journalctl -t bos-tui -f                     # seguimiento en vivo del TUI
//	journalctl -t bos-tui -p warning -n 100      # últimas 100 advertencias
//	journalctl -t bos -n 200                      # todos los componentes BOS
//	journalctl -u bos.service -u bkernel.service  # por unidad systemd
//
// Arquitectura:
//
//	┌─────────────────────────────────────────────────┐
//	│  TUI componentes (ws, auth, install, boot…)     │
//	│  llaman: m.TUILog.Info("ws", "conectado")       │
//	└───────────────────┬─────────────────────────────┘
//	                    │
//	         ┌──────────▼──────────────┐
//	         │   Ring (buffer circular) │ ← copia en memoria (rápida)
//	         │   + syslog writer       │ ← journald (persistente)
//	         └──────────┬──────────────┘
//	                    │ notifica
//	         ┌──────────▼──────────────┐
//	         │   WatchCmd / suscriptor │ ← BubbleTea tea.Cmd
//	         └──────────┬──────────────┘
//	                    │ TUILogTickMsg
//	         ┌──────────▼──────────────┐
//	         │   ctrl/panel/logs.go    │ ← renderiza con estilos SBOS
//	         └─────────────────────────┘
//
// Para el viewer completo (leer journalctl, no solo el TUI):
//
//	ch, cancel := tuilog.Follow("bos-tui", 100)  // o una unidad: "bos.service"
//	defer cancel()
//	cmd := tuilog.FollowCmd(ch)                  // tea.Cmd que emite JournalEntryMsg
//
// Formato del mensaje en journald:
//
//	SYSLOG_IDENTIFIER=bos-tui
//	PRIORITY=<prioridad syslog 0-7>
//	MESSAGE={"src":"<source>","msg":"<mensaje>"}
package tuilog

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log/syslog"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

// ════════════════════════════════════════════════════════════════════════════
// NIVEL
// ════════════════════════════════════════════════════════════════════════════

// Level clasifica la importancia de un evento del TUI.
// Mapeado al sistema de estado SBOS: Debug→Off, Info→Info, Warn→Warn, Error→Err, Crit→Crit.
type Level uint8

const (
	LevelDebug Level = iota // trazas de desarrollo — muted en producción
	LevelInfo               // operación normal
	LevelWarn               // condición anómala no fatal
	LevelError              // fallo recuperable
	LevelCrit               // fallo no recuperable — acción inmediata
)

// String retorna la etiqueta de texto del nivel (5 chars fijos).
func (l Level) String() string {
	switch l {
	case LevelDebug:
		return "DEBUG"
	case LevelInfo:
		return "INFO "
	case LevelWarn:
		return "WARN "
	case LevelError:
		return "ERROR"
	case LevelCrit:
		return "CRIT "
	}
	return "?????"
}

// syslogPriority mapea Level → prioridad syslog (RFC 5424).
func (l Level) syslogPriority() syslog.Priority {
	switch l {
	case LevelDebug:
		return syslog.LOG_DEBUG
	case LevelInfo:
		return syslog.LOG_INFO
	case LevelWarn:
		return syslog.LOG_WARNING
	case LevelError:
		return syslog.LOG_ERR
	case LevelCrit:
		return syslog.LOG_CRIT
	}
	return syslog.LOG_INFO
}

// LevelFromSyslog convierte prioridad syslog/journald (0-7) → Level.
func LevelFromSyslog(p int) Level {
	switch {
	case p <= 2:
		return LevelCrit // emerg(0)+alert(1)+crit(2) → Crit
	case p == 3:
		return LevelError // err(3) → Error
	case p == 4:
		return LevelWarn // warning(4) → Warn
	case p <= 6:
		return LevelInfo // notice(5)+info(6) → Info
	}
	return LevelDebug // debug(7)
}

// ════════════════════════════════════════════════════════════════════════════
// ENTRADA
// ════════════════════════════════════════════════════════════════════════════

// Entry es un evento de log capturado por el Ring o leído de journald.
type Entry struct {
	Ts      time.Time // timestamp UTC
	Level   Level     // clasificación del evento
	Source  string    // subsistema: "ws", "auth", "install", "boot", "preflight", "ui"
	Message string    // descripción del evento
	Unit    string    // unidad systemd (vacío si viene del Ring propio)
}

// msgJSON es el JSON que escribimos como body del mensaje en journald.
type msgJSON struct {
	Src string `json:"src"`
	Msg string `json:"msg"`
}

// ════════════════════════════════════════════════════════════════════════════
// RING — buffer circular + syslog writer
// ════════════════════════════════════════════════════════════════════════════

// Ring es el logger de seguimiento del TUI.
// Escribe simultáneamente en journald (persistente) y en un buffer circular
// en memoria (rápido, para el viewer inline del TUI).
type Ring struct {
	mu    sync.RWMutex
	buf   []Entry
	cap   int
	head  int // posición de escritura siguiente
	count int // entradas almacenadas (0..cap)

	w *syslog.Writer // nil = sin journald (CI, sin systemd)

	subsMu sync.Mutex
	subs   []chan struct{}
}

// NewRing construye un Ring con la capacidad dada.
// Intenta conectar a syslog/journald; si falla, usa solo el buffer en memoria.
func NewRing(capacity int) *Ring {
	if capacity < 16 {
		capacity = 16
	}
	r := &Ring{
		buf: make([]Entry, capacity),
		cap: capacity,
	}
	// Conectar a syslog → journald con identificador "bos-tui"
	if w, err := syslog.New(syslog.LOG_INFO|syslog.LOG_DAEMON, "bos-tui"); err == nil {
		r.w = w
	}
	return r
}

// Log registra una entrada. Si args no es vacío, message es un formato Sprintf.
// Escribe en journald (si disponible) y en el buffer circular.
func (r *Ring) Log(level Level, source, message string, args ...any) {
	if len(args) > 0 {
		message = fmt.Sprintf(message, args...)
	}

	// Serializar como JSON para journald (parseable al leer con journalctl)
	if r.w != nil {
		body, _ := json.Marshal(msgJSON{Src: source, Msg: message})
		switch level.syslogPriority() {
		case syslog.LOG_DEBUG:
			r.w.Debug(string(body)) //nolint:errcheck
		case syslog.LOG_INFO:
			r.w.Info(string(body)) //nolint:errcheck
		case syslog.LOG_WARNING:
			r.w.Warning(string(body)) //nolint:errcheck
		case syslog.LOG_ERR:
			r.w.Err(string(body)) //nolint:errcheck
		default:
			r.w.Crit(string(body)) //nolint:errcheck
		}
	}

	e := Entry{Ts: time.Now().UTC(), Level: level, Source: source, Message: message}

	r.mu.Lock()
	r.buf[r.head] = e
	r.head = (r.head + 1) % r.cap
	if r.count < r.cap {
		r.count++
	}
	r.mu.Unlock()

	r.notifySubs()
}

// Helpers por nivel.
func (r *Ring) Debug(src, msg string, a ...any) { r.Log(LevelDebug, src, msg, a...) }
func (r *Ring) Info(src, msg string, a ...any)  { r.Log(LevelInfo, src, msg, a...) }
func (r *Ring) Warn(src, msg string, a ...any)  { r.Log(LevelWarn, src, msg, a...) }
func (r *Ring) Error(src, msg string, a ...any) { r.Log(LevelError, src, msg, a...) }
func (r *Ring) Crit(src, msg string, a ...any)  { r.Log(LevelCrit, src, msg, a...) }

// Entries retorna una copia de todas las entradas en orden cronológico.
func (r *Ring) Entries() []Entry {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.count == 0 {
		return nil
	}
	out := make([]Entry, r.count)
	if r.count < r.cap {
		copy(out, r.buf[:r.count])
	} else {
		n := copy(out, r.buf[r.head:])
		copy(out[n:], r.buf[:r.head])
	}
	return out
}

// Last retorna las últimas n entradas en orden cronológico.
func (r *Ring) Last(n int) []Entry {
	all := r.Entries()
	if n <= 0 || len(all) <= n {
		return all
	}
	return all[len(all)-n:]
}

// Filter retorna las entradas con nivel >= minLevel, en orden cronológico.
func (r *Ring) Filter(minLevel Level) []Entry {
	all := r.Entries()
	out := all[:0]
	for _, e := range all {
		if e.Level >= minLevel {
			out = append(out, e)
		}
	}
	return out
}

// Count retorna el número de entradas actuales en el buffer.
func (r *Ring) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.count
}

// Close cierra la conexión con syslog/journald.
func (r *Ring) Close() error {
	if r.w != nil {
		return r.w.Close()
	}
	return nil
}

// ════════════════════════════════════════════════════════════════════════════
// SUSCRIPTORES BUBBLETEA
// ════════════════════════════════════════════════════════════════════════════

// Sub registra un suscriptor y retorna el canal de notificación.
// Cada vez que se escriba una entrada el canal recibe una señal (non-blocking).
func (r *Ring) Sub() chan struct{} {
	ch := make(chan struct{}, 1)
	r.subsMu.Lock()
	r.subs = append(r.subs, ch)
	r.subsMu.Unlock()
	return ch
}

func (r *Ring) notifySubs() {
	r.subsMu.Lock()
	defer r.subsMu.Unlock()
	for _, ch := range r.subs {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

// TUILogTickMsg se envía al modelo TEA cuando el Ring tiene nuevas entradas.
type TUILogTickMsg struct{}

// WatchCmd retorna un tea.Cmd que bloquea en el canal de suscripción hasta
// recibir una señal del Ring, luego emite TUILogTickMsg.
// Debe encadenarse siempre en el handler del mensaje:
//
//	case tuilog.TUILogTickMsg:
//	    return m, tuilog.WatchCmd(m.TUILogCh)
func WatchCmd(ch chan struct{}) tea.Cmd {
	return func() tea.Msg {
		<-ch
		return TUILogTickMsg{}
	}
}

// ════════════════════════════════════════════════════════════════════════════
// LECTOR DE JOURNALCTL — viewer de logs del sistema
// ════════════════════════════════════════════════════════════════════════════

// JournalEntryMsg transporta una entrada leída de journalctl al modelo TEA.
type JournalEntryMsg struct {
	Entry Entry
}

// JournalErrMsg indica que journalctl terminó o tuvo un error.
type JournalErrMsg struct {
	Err string
}

// Follow lanza journalctl en modo follow y retorna un canal de entradas.
// target puede ser:
//   - un identificador syslog: "bos-tui", "bos-ws", "bos" (todos los bos-*)
//   - una unidad systemd: "bos.service", "bkernel.service"
//   - cadena vacía: todos los logs del sistema
//
// Retorna el canal (entrada por línea JSON) y una función cancel() para detener.
func Follow(target string, lastN int) (<-chan Entry, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())
	ch := make(chan Entry, 64)

	go func() {
		defer close(ch)

		args := buildArgs(target, lastN, true)
		cmd := exec.CommandContext(ctx, "journalctl", args...)
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			select {
			case ch <- Entry{Ts: time.Now(), Level: LevelError, Source: "journal", Message: "pipe: " + err.Error()}:
			case <-ctx.Done():
			}
			return
		}
		if err := cmd.Start(); err != nil {
			select {
			case ch <- Entry{Ts: time.Now(), Level: LevelError, Source: "journal", Message: "journalctl: " + err.Error()}:
			case <-ctx.Done():
			}
			return
		}

		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 256*1024), 256*1024)
		for scanner.Scan() {
			if ctx.Err() != nil {
				return
			}
			e, ok := parseJSONLine(scanner.Bytes())
			if !ok {
				continue
			}
			select {
			case ch <- e:
			case <-ctx.Done():
				return
			}
		}
	}()

	return ch, cancel
}

// FollowCmd retorna un tea.Cmd que lee UNA entrada del canal y emite JournalEntryMsg.
// El handler debe encadenarlo de nuevo para seguir leyendo:
//
//	case tuilog.JournalEntryMsg:
//	    m.JournalEntries = append(m.JournalEntries, msg.Entry)
//	    return m, tuilog.FollowCmd(m.JournalCh)
//
//	case tuilog.JournalErrMsg:
//	    // canal cerrado — no relanzar
func FollowCmd(ch <-chan Entry) tea.Cmd {
	return func() tea.Msg {
		e, ok := <-ch
		if !ok {
			return JournalErrMsg{Err: "journalctl terminó"}
		}
		return JournalEntryMsg{Entry: e}
	}
}

// buildArgs construye los argumentos para journalctl.
func buildArgs(target string, lastN int, follow bool) []string {
	args := []string{"--output=json", "--no-pager"}
	if follow {
		args = append(args, "--follow")
	}
	if lastN > 0 {
		args = append(args, fmt.Sprintf("-n%d", lastN))
	}
	if target != "" {
		// Si termina en ".service" o similar → --unit; si no → -t (syslog identifier)
		if strings.Contains(target, ".") {
			args = append(args, "--unit="+target)
		} else {
			args = append(args, "-t", target)
		}
	}
	return args
}

// parseJSONLine parsea una línea JSON de journalctl --output=json.
// Retorna false si la línea está vacía o no es un log válido.
func parseJSONLine(data []byte) (Entry, bool) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return Entry{}, false
	}

	// Timestamp: __REALTIME_TIMESTAMP en microsegundos desde epoch
	var ts time.Time
	if v, ok := raw["__REALTIME_TIMESTAMP"]; ok {
		var s string
		if json.Unmarshal(v, &s) == nil {
			if us, err := strconv.ParseInt(s, 10, 64); err == nil {
				ts = time.Unix(us/1e6, (us%1e6)*1000).UTC()
			}
		}
	}
	if ts.IsZero() {
		ts = time.Now().UTC()
	}

	// Nivel: PRIORITY (syslog 0-7)
	level := LevelInfo
	if v, ok := raw["PRIORITY"]; ok {
		var s string
		if json.Unmarshal(v, &s) == nil {
			if p, err := strconv.Atoi(s); err == nil {
				level = LevelFromSyslog(p)
			}
		}
	}

	// Unidad: _SYSTEMD_UNIT o SYSLOG_IDENTIFIER
	unit := jsonStr(raw, "_SYSTEMD_UNIT")
	if unit == "" {
		unit = jsonStr(raw, "SYSLOG_IDENTIFIER")
	}

	// Mensaje: MESSAGE (string o array de bytes)
	msg := parseMessage(raw["MESSAGE"])
	if msg == "" {
		return Entry{}, false
	}

	// Intentar parsear nuestro formato JSON interno: {"src":"...","msg":"..."}
	source, cleanMsg := parseOurFormat(msg)
	if source == "" {
		source = unit // fallback: usar la unidad como source
	}

	return Entry{
		Ts:      ts,
		Level:   level,
		Source:  source,
		Message: cleanMsg,
		Unit:    unit,
	}, true
}

// parseMessage extrae el string MESSAGE de journalctl JSON.
// Journald puede codificarlo como string o como []byte (datos binarios).
func parseMessage(raw json.RawMessage) string {
	if raw == nil {
		return ""
	}
	// Intentar como string primero
	var s string
	if err := json.Unmarshal(raw, &s); err == nil {
		return s
	}
	// Fallback: array de bytes
	var bytes []byte
	if err := json.Unmarshal(raw, &bytes); err == nil {
		return string(bytes)
	}
	return ""
}

// parseOurFormat intenta parsear el JSON interno que escribimos: {"src":"...","msg":"..."}.
// Si no es nuestro formato, retorna source="" y devuelve el mensaje original.
func parseOurFormat(raw string) (source, msg string) {
	var m msgJSON
	if err := json.Unmarshal([]byte(raw), &m); err == nil && m.Msg != "" {
		return m.Src, m.Msg
	}
	return "", raw
}

// jsonStr extrae un campo string de un mapa JSON crudo.
func jsonStr(m map[string]json.RawMessage, key string) string {
	v, ok := m[key]
	if !ok {
		return ""
	}
	var s string
	json.Unmarshal(v, &s) //nolint:errcheck
	return s
}

// ════════════════════════════════════════════════════════════════════════════
// FUENTES CANÓNICAS
// ════════════════════════════════════════════════════════════════════════════

// Identificador journald del TUI (filtrar con: journalctl -t bos-tui)
const JournalID = "bos-tui"

// Fuentes canónicas — usar estas constantes en lugar de strings literales.
const (
	SrcTUI       = "tui"       // loop principal, navegación, resize
	SrcWS        = "ws"        // WebSocket con daemon bos
	SrcAuth      = "auth"      // autenticación y step-up LoA
	SrcInstall   = "install"   // instalación de fichas, sagas
	SrcBoot      = "boot"      // arranque del sistema
	SrcPreflight = "preflight" // comprobaciones previas al bootstrap
	SrcUI        = "ui"        // eventos de UI: resize, focus, input
	SrcObserver  = "observer"  // métricas /proc, health checks
)
