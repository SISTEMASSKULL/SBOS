package tuilog

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ════════════════════════════════════════════════════════════════════════════
// Level
// ════════════════════════════════════════════════════════════════════════════

func TestLevel_String(t *testing.T) {
	cases := []struct {
		lvl  Level
		want string
	}{
		{LevelDebug, "DEBUG"},
		{LevelInfo, "INFO "},
		{LevelWarn, "WARN "},
		{LevelError, "ERROR"},
		{LevelCrit, "CRIT "},
		{Level(99), "?????"},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, c.lvl.String(), "Level(%d).String()", c.lvl)
	}
}

func TestLevel_SyslogPriority_TodosLosCasos(t *testing.T) {
	// Verificar que cada Level produce una prioridad syslog diferente y correcta.
	cases := []struct {
		lvl      Level
		wantPrio int // syslog priorities: 0=emerg..7=debug
	}{
		{LevelDebug, 7},
		{LevelInfo, 6},
		{LevelWarn, 4},
		{LevelError, 3},
		{LevelCrit, 2},
	}
	for _, c := range cases {
		// syslog.Priority tiene el facility en bits altos; comparamos solo los 3 bits bajos
		got := int(c.lvl.syslogPriority()) & 0x07
		assert.Equal(t, c.wantPrio, got, "Level(%d).syslogPriority() severity", c.lvl)
	}
}

func TestLevelFromSyslog(t *testing.T) {
	cases := []struct {
		priority int
		want     Level
	}{
		{0, LevelCrit},  // emerg
		{1, LevelCrit},  // alert
		{2, LevelCrit},  // crit
		{3, LevelError}, // err
		{4, LevelWarn},  // warning
		{5, LevelInfo},  // notice
		{6, LevelInfo},  // info
		{7, LevelDebug}, // debug
		{8, LevelDebug}, // fuera de rango → debug
	}
	for _, c := range cases {
		assert.Equal(t, c.want, LevelFromSyslog(c.priority), "LevelFromSyslog(%d)", c.priority)
	}
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — construcción
// ════════════════════════════════════════════════════════════════════════════

func TestNewRing_CapacidadMinima(t *testing.T) {
	// Capacidades menores a 16 deben ajustarse a 16
	r := NewRing(0)
	assert.Equal(t, 16, r.cap)

	r2 := NewRing(-5)
	assert.Equal(t, 16, r2.cap)
}

func TestNewRing_CapacidadRespetada(t *testing.T) {
	r := NewRing(64)
	assert.Equal(t, 64, r.cap)
	assert.Equal(t, 0, r.Count())
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — escritura y lectura básica
// ════════════════════════════════════════════════════════════════════════════

func newTestRing(cap int) *Ring {
	// Ring sin syslog (entorno de test sin journald)
	return &Ring{buf: make([]Entry, cap), cap: cap}
}

func TestRing_Log_UnaEntrada(t *testing.T) {
	r := newTestRing(16)
	before := time.Now().UTC().Truncate(time.Second)

	r.Log(LevelInfo, "test", "hola mundo")

	assert.Equal(t, 1, r.Count())
	entries := r.Entries()
	require.Len(t, entries, 1)

	e := entries[0]
	assert.Equal(t, LevelInfo, e.Level)
	assert.Equal(t, "test", e.Source)
	assert.Equal(t, "hola mundo", e.Message)
	assert.True(t, !e.Ts.Before(before), "timestamp debe ser >= before")
}

func TestRing_Log_FormatoSprintf(t *testing.T) {
	r := newTestRing(16)
	r.Log(LevelWarn, "ws", "código %d: %s", 42, "error de red")

	entries := r.Entries()
	require.Len(t, entries, 1)
	assert.Equal(t, "código 42: error de red", entries[0].Message)
}

func TestRing_Helpers_NivelesCorrecto(t *testing.T) {
	r := newTestRing(16)
	r.Debug("src", "debug msg")
	r.Info("src", "info msg")
	r.Warn("src", "warn msg")
	r.Error("src", "error msg")
	r.Crit("src", "crit msg")

	entries := r.Entries()
	require.Len(t, entries, 5)
	assert.Equal(t, LevelDebug, entries[0].Level)
	assert.Equal(t, LevelInfo, entries[1].Level)
	assert.Equal(t, LevelWarn, entries[2].Level)
	assert.Equal(t, LevelError, entries[3].Level)
	assert.Equal(t, LevelCrit, entries[4].Level)
}

func TestRing_Entries_OrdenCronologico(t *testing.T) {
	r := newTestRing(16)
	for i := 0; i < 5; i++ {
		r.Info("src", "msg %d", i)
	}
	entries := r.Entries()
	require.Len(t, entries, 5)
	for i, e := range entries {
		assert.Equal(t, fmt.Sprintf("msg %d", i), e.Message)
	}
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — buffer circular (overflow)
// ════════════════════════════════════════════════════════════════════════════

func TestRing_Overflow_SobreescribeAntiguas(t *testing.T) {
	const cap = 4
	r := newTestRing(cap)

	// Llenar exactamente el buffer
	for i := 0; i < cap; i++ {
		r.Info("src", "msg %d", i)
	}
	assert.Equal(t, cap, r.Count())

	// Escribir una más → debe sobreescribir la más antigua (msg 0)
	r.Info("src", "msg 4")

	entries := r.Entries()
	assert.Equal(t, cap, r.Count())
	assert.Len(t, entries, cap)

	// La primera entrada ahora debe ser msg 1 (msg 0 fue sobreescrita)
	assert.Equal(t, "msg 1", entries[0].Message)
	assert.Equal(t, "msg 4", entries[cap-1].Message)
}

func TestRing_Overflow_Doble(t *testing.T) {
	const cap = 4
	r := newTestRing(cap)

	// Escribir 2×cap entradas
	for i := 0; i < cap*2; i++ {
		r.Info("src", "msg %d", i)
	}

	entries := r.Entries()
	assert.Equal(t, cap, r.Count())
	assert.Len(t, entries, cap)

	// Deben ser los últimos 4 mensajes: 4, 5, 6, 7
	for i, e := range entries {
		assert.Equal(t, fmt.Sprintf("msg %d", cap+i), e.Message,
			"entrada %d debe ser msg %d", i, cap+i)
	}
}

func TestRing_Overflow_OrdenCronologicoCorrecto(t *testing.T) {
	const cap = 3
	r := newTestRing(cap)
	// Llenar y overflow
	for i := 0; i < 7; i++ {
		r.Info("src", "msg %d", i)
	}
	entries := r.Entries()
	// Deben ser msg 4, msg 5, msg 6 en ese orden
	require.Len(t, entries, 3)
	assert.Equal(t, "msg 4", entries[0].Message)
	assert.Equal(t, "msg 5", entries[1].Message)
	assert.Equal(t, "msg 6", entries[2].Message)
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — Last
// ════════════════════════════════════════════════════════════════════════════

func TestRing_Last_MenosQueCount(t *testing.T) {
	r := newTestRing(16)
	for i := 0; i < 10; i++ {
		r.Info("src", "msg %d", i)
	}
	last := r.Last(3)
	require.Len(t, last, 3)
	assert.Equal(t, "msg 7", last[0].Message)
	assert.Equal(t, "msg 8", last[1].Message)
	assert.Equal(t, "msg 9", last[2].Message)
}

func TestRing_Last_MasQueCount(t *testing.T) {
	r := newTestRing(16)
	r.Info("src", "msg 0")
	r.Info("src", "msg 1")

	last := r.Last(50)
	assert.Len(t, last, 2) // no puede retornar más de lo que hay
}

func TestRing_Last_Cero(t *testing.T) {
	r := newTestRing(16)
	r.Info("src", "msg")
	last := r.Last(0)
	assert.Len(t, last, 1) // Last(0) retorna todas cuando count <= 0
}

func TestRing_Last_RingVacio(t *testing.T) {
	r := newTestRing(16)
	last := r.Last(10)
	assert.Empty(t, last)
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — Filter
// ════════════════════════════════════════════════════════════════════════════

func TestRing_Filter_PorNivel(t *testing.T) {
	r := newTestRing(32)
	r.Debug("src", "debug")
	r.Info("src", "info")
	r.Warn("src", "warn")
	r.Error("src", "error")
	r.Crit("src", "crit")

	// Filter(LevelWarn) debe retornar Warn, Error, Crit
	filtered := r.Filter(LevelWarn)
	require.Len(t, filtered, 3)
	assert.Equal(t, LevelWarn, filtered[0].Level)
	assert.Equal(t, LevelError, filtered[1].Level)
	assert.Equal(t, LevelCrit, filtered[2].Level)
}

func TestRing_Filter_SoloError(t *testing.T) {
	r := newTestRing(16)
	r.Info("src", "info")
	r.Warn("src", "warn")
	r.Error("src", "error")

	filtered := r.Filter(LevelError)
	require.Len(t, filtered, 1)
	assert.Equal(t, "error", filtered[0].Message)
}

func TestRing_Filter_TodosDebug(t *testing.T) {
	r := newTestRing(16)
	r.Debug("src", "d")
	r.Info("src", "i")
	r.Crit("src", "c")

	filtered := r.Filter(LevelDebug) // desde Debug → todas
	assert.Len(t, filtered, 3)
}

func TestRing_Filter_RingVacio(t *testing.T) {
	r := newTestRing(16)
	filtered := r.Filter(LevelInfo)
	assert.Empty(t, filtered)
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — suscriptores y WatchCmd
// ════════════════════════════════════════════════════════════════════════════

func TestRing_Sub_NotificaCadaEscritura(t *testing.T) {
	r := newTestRing(16)
	ch := r.Sub()

	r.Info("src", "primer evento")

	select {
	case <-ch:
		// OK — recibimos la notificación
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Sub() no recibió notificación tras Log()")
	}
}

func TestRing_Sub_NoBloquea_SiConsumorLento(t *testing.T) {
	r := newTestRing(16)
	_ = r.Sub() // suscriptor que nunca lee

	// El escritor no debe bloquearse aunque el suscriptor no consuma
	done := make(chan struct{})
	go func() {
		for i := 0; i < 100; i++ {
			r.Info("src", "msg %d", i)
		}
		close(done)
	}()

	select {
	case <-done:
		// OK
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Log() bloqueó con suscriptor lento")
	}
}

func TestRing_Sub_MultiplesSubscriptores(t *testing.T) {
	r := newTestRing(16)
	const N = 3
	chs := make([]chan struct{}, N)
	for i := range chs {
		chs[i] = r.Sub()
	}

	r.Warn("src", "broadcast")

	for i, ch := range chs {
		select {
		case <-ch:
		case <-time.After(100 * time.Millisecond):
			t.Fatalf("suscriptor %d no recibió notificación", i)
		}
	}
}

func TestWatchCmd_EmiteTUILogTickMsg(t *testing.T) {
	r := newTestRing(16)
	ch := r.Sub()

	cmd := WatchCmd(ch)

	// Lanzar WatchCmd en goroutine (bloquea hasta notificación)
	msgCh := make(chan any, 1)
	go func() {
		msgCh <- cmd()
	}()

	// Disparar la notificación
	r.Info("src", "trigger")

	select {
	case got := <-msgCh:
		_, ok := got.(TUILogTickMsg)
		assert.True(t, ok, "WatchCmd debe emitir TUILogTickMsg, got %T", got)
	case <-time.After(200 * time.Millisecond):
		t.Fatal("WatchCmd no emitió mensaje en tiempo")
	}
}

// ════════════════════════════════════════════════════════════════════════════
// Ring — concurrencia
// ════════════════════════════════════════════════════════════════════════════

func TestRing_ConcurrenciaEscrituras(t *testing.T) {
	r := newTestRing(256)
	const goroutines = 8
	const perG = 50

	var wg sync.WaitGroup
	for g := 0; g < goroutines; g++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for i := 0; i < perG; i++ {
				r.Info("src", "g%d-msg%d", id, i)
			}
		}(g)
	}
	wg.Wait()

	// El ring debe tener exactamente min(goroutines*perG, cap) entradas
	expected := goroutines * perG
	if expected > r.cap {
		expected = r.cap
	}
	assert.Equal(t, expected, r.Count())
}

func TestRing_ConcurrenciaLecturaEscritura(t *testing.T) {
	r := newTestRing(64)
	stop := make(chan struct{})

	// Escritores
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
					r.Info("writer", "msg")
				}
			}
		}()
	}

	// Lectores (no deben paniquear ni bloquearse)
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
					_ = r.Entries()
					_ = r.Last(10)
					_ = r.Count()
				}
			}
		}()
	}

	time.Sleep(100 * time.Millisecond)
	close(stop)
	wg.Wait()
	// Si llegamos aquí sin panic ni deadlock, el test pasa
}

// ════════════════════════════════════════════════════════════════════════════
// parseJSONLine — parseo de journalctl JSON
// ════════════════════════════════════════════════════════════════════════════

func buildJournalJSON(priority, unit, message, ts string) []byte {
	m := map[string]string{
		"PRIORITY":              priority,
		"_SYSTEMD_UNIT":         unit,
		"MESSAGE":               message,
		"__REALTIME_TIMESTAMP":  ts,
	}
	b, _ := json.Marshal(m)
	return b
}

func TestParseJSONLine_EntradaBasica(t *testing.T) {
	// Entrada con nuestro formato JSON interno
	inner, _ := json.Marshal(msgJSON{Src: "ws", Msg: "conectado a bos.sock"})
	data := buildJournalJSON("6", "bos.service", string(inner), "1718000000000000")

	e, ok := parseJSONLine(data)
	require.True(t, ok)
	assert.Equal(t, LevelInfo, e.Level)
	assert.Equal(t, "ws", e.Source)
	assert.Equal(t, "conectado a bos.sock", e.Message)
	assert.Equal(t, "bos.service", e.Unit)
}

func TestParseJSONLine_MensajePlano(t *testing.T) {
	// Mensaje que NO es nuestro JSON interno — texto plano de otro proceso
	data := buildJournalJSON("3", "postgresql.service", "FATAL: database not found", "1718000001000000")

	e, ok := parseJSONLine(data)
	require.True(t, ok)
	assert.Equal(t, LevelError, e.Level)
	assert.Equal(t, "postgresql.service", e.Source) // fallback a unit
	assert.Equal(t, "FATAL: database not found", e.Message)
}

func TestParseJSONLine_PrioridadesSyslog(t *testing.T) {
	cases := []struct {
		prio      string
		wantLevel Level
	}{
		{"0", LevelCrit},
		{"1", LevelCrit},
		{"2", LevelCrit},
		{"3", LevelError},
		{"4", LevelWarn},
		{"5", LevelInfo},
		{"6", LevelInfo},
		{"7", LevelDebug},
	}
	for _, c := range cases {
		data := buildJournalJSON(c.prio, "bos.service", "msg", "1718000000000000")
		e, ok := parseJSONLine(data)
		require.True(t, ok, "prioridad %s", c.prio)
		assert.Equal(t, c.wantLevel, e.Level, "prioridad syslog %s", c.prio)
	}
}

func TestParseJSONLine_TimestampCorrecto(t *testing.T) {
	// 1718000000000000 microsegundos = 2024-06-10 ~ (algún momento)
	data := buildJournalJSON("6", "bos.service", "msg", "1718000000000000")
	e, ok := parseJSONLine(data)
	require.True(t, ok)
	// Verificar que el timestamp es razonable (año 2024)
	assert.Equal(t, 2024, e.Ts.Year())
}

func TestParseJSONLine_TimestampVacio_UsaNow(t *testing.T) {
	before := time.Now().UTC().Add(-time.Second)
	m := map[string]string{"PRIORITY": "6", "MESSAGE": "msg"}
	data, _ := json.Marshal(m)
	e, ok := parseJSONLine(data)
	require.True(t, ok)
	assert.True(t, e.Ts.After(before), "timestamp debe ser reciente cuando __REALTIME_TIMESTAMP falta")
}

func TestParseJSONLine_LineaVacia(t *testing.T) {
	_, ok := parseJSONLine([]byte{})
	assert.False(t, ok)
}

func TestParseJSONLine_JSONInvalido(t *testing.T) {
	_, ok := parseJSONLine([]byte("{no es json"))
	assert.False(t, ok)
}

func TestParseJSONLine_SinMensaje(t *testing.T) {
	m := map[string]string{"PRIORITY": "6", "_SYSTEMD_UNIT": "bos.service"}
	data, _ := json.Marshal(m)
	_, ok := parseJSONLine(data)
	assert.False(t, ok, "sin MESSAGE no debe parsear")
}

// ════════════════════════════════════════════════════════════════════════════
// parseMessage — campo MESSAGE de journalctl
// ════════════════════════════════════════════════════════════════════════════

func TestParseMessage_ComoString(t *testing.T) {
	raw, _ := json.Marshal("hola mundo")
	result := parseMessage(raw)
	assert.Equal(t, "hola mundo", result)
}

func TestParseMessage_ComoArrayDeEnteros(t *testing.T) {
	// journald codifica mensajes binarios como array de enteros JSON (no base64).
	// Ej: "hola" → [104, 111, 108, 97]
	// json.Marshal([]byte) produce base64, pero journald usa [104, 111, 108, 97].
	// Construimos el array manualmente para reproducir el formato real de journald.
	raw := json.RawMessage(`[104,111,108,97,32,109,117,110,100,111]`) // "hola mundo"
	result := parseMessage(raw)
	assert.Equal(t, "hola mundo", result)
}

func TestParseMessage_Nil(t *testing.T) {
	result := parseMessage(nil)
	assert.Equal(t, "", result)
}

// ════════════════════════════════════════════════════════════════════════════
// parseOurFormat — formato JSON interno
// ════════════════════════════════════════════════════════════════════════════

func TestParseOurFormat_JsonValido(t *testing.T) {
	inner, _ := json.Marshal(msgJSON{Src: "auth", Msg: "login exitoso"})
	src, msg := parseOurFormat(string(inner))
	assert.Equal(t, "auth", src)
	assert.Equal(t, "login exitoso", msg)
}

func TestParseOurFormat_TextoPlano(t *testing.T) {
	src, msg := parseOurFormat("texto plano sin json")
	assert.Equal(t, "", src)
	assert.Equal(t, "texto plano sin json", msg)
}

func TestParseOurFormat_JsonSinMsg(t *testing.T) {
	// JSON válido pero sin campo "msg" — no es nuestro formato
	src, msg := parseOurFormat(`{"other":"value"}`)
	assert.Equal(t, "", src)
	assert.Equal(t, `{"other":"value"}`, msg)
}

func TestParseOurFormat_SrcVacio(t *testing.T) {
	// src vacío es válido — msg tiene contenido
	inner, _ := json.Marshal(msgJSON{Src: "", Msg: "mensaje sin fuente"})
	src, msg := parseOurFormat(string(inner))
	assert.Equal(t, "", src)
	assert.Equal(t, "mensaje sin fuente", msg)
}

// ════════════════════════════════════════════════════════════════════════════
// Constantes de fuente
// ════════════════════════════════════════════════════════════════════════════

func TestConstantesFuente_NoVacias(t *testing.T) {
	sources := []string{SrcTUI, SrcWS, SrcAuth, SrcInstall, SrcBoot, SrcPreflight, SrcUI, SrcObserver}
	for _, s := range sources {
		assert.NotEmpty(t, s, "constante de fuente no debe estar vacía")
	}
}

func TestJournalID_EsCorrecto(t *testing.T) {
	assert.Equal(t, "bos-tui", JournalID)
}

// ════════════════════════════════════════════════════════════════════════════
// buildArgs — construcción de argumentos journalctl
// ════════════════════════════════════════════════════════════════════════════

func TestBuildArgs_ConUnidadService(t *testing.T) {
	args := buildArgs("bos.service", 100, true)
	assert.Contains(t, args, "--follow")
	assert.Contains(t, args, "--unit=bos.service")
	assert.Contains(t, args, "-n100")
}

func TestBuildArgs_ConIdentificadorSyslog(t *testing.T) {
	args := buildArgs("bos-tui", 50, false)
	assert.NotContains(t, args, "--follow")
	assert.Contains(t, args, "-t")
	assert.Contains(t, args, "bos-tui")
	assert.Contains(t, args, "-n50")
}

func TestBuildArgs_SinTarget(t *testing.T) {
	args := buildArgs("", 0, true)
	// Sin target — sin -t ni --unit
	for _, a := range args {
		assert.False(t, strings.HasPrefix(a, "--unit"), "no debe incluir --unit sin target")
		assert.False(t, a == "-t", "no debe incluir -t sin target")
	}
}

func TestBuildArgs_SinLastN(t *testing.T) {
	args := buildArgs("bos-tui", 0, false)
	// Sin -n cuando lastN=0
	for _, a := range args {
		assert.False(t, strings.HasPrefix(a, "-n"), "no debe incluir -n cuando lastN=0")
	}
}
