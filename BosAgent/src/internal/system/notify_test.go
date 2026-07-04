package system

import (
	"net"
	"os"
	"strconv"
	"testing"
	"time"
)

// TestStartWatchdog_EnviaWATCHDOG1 verifica que StartWatchdog envía "WATCHDOG=1"
// al socket de notificación de systemd dentro del intervalo esperado.
// No usa t.Parallel — t.Setenv no es compatible con ejecución paralela.
func TestStartWatchdog_EnviaWATCHDOG1(t *testing.T) {
	dir := t.TempDir()
	sockPath := dir + "/notify.sock"

	conn, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: sockPath, Net: "unixgram"})
	if err != nil {
		t.Fatalf("no se pudo crear socket de notificación: %v", err)
	}
	defer conn.Close()

	// 40ms de intervalo → tick cada 20ms; deadline 2s → ~100 oportunidades.
	// El margen amplio elimina la sensibilidad a contención del runner
	// (-race -count=10 multi-paquete) sin debilitar el contrato: el watchdog
	// debe emitir WATCHDOG=1 periódicamente.
	intervalUs := int64(40_000)
	t.Setenv("WATCHDOG_USEC", strconv.FormatInt(intervalUs, 10))
	t.Setenv("NOTIFY_SOCKET", sockPath)

	stopCh := make(chan struct{})
	go StartWatchdog(stopCh)

	conn.SetDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 64)
	n, err := conn.Read(buf)
	close(stopCh)

	if err != nil {
		t.Fatalf("no se recibió WATCHDOG=1 en 500ms: %v", err)
	}
	if got := string(buf[:n]); got != "WATCHDOG=1" {
		t.Errorf("esperado WATCHDOG=1, recibido %q", got)
	}
}

// TestStartWatchdog_SinEnvNoOp verifica que StartWatchdog no hace nada
// cuando WATCHDOG_USEC no está definido (fuera de systemd).
func TestStartWatchdog_SinEnvNoOp(t *testing.T) {
	t.Parallel()
	os.Unsetenv("WATCHDOG_USEC")

	stopCh := make(chan struct{})
	done := make(chan struct{})
	go func() {
		StartWatchdog(stopCh)
		close(done)
	}()

	select {
	case <-done:
		// ✅ retornó inmediatamente sin WATCHDOG_USEC
	case <-time.After(200 * time.Millisecond):
		t.Error("StartWatchdog no retornó sin WATCHDOG_USEC — debería ser no-op")
		close(stopCh)
	}
}
