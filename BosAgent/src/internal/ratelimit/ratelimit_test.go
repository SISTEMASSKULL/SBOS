package ratelimit

import (
	"fmt"
	"net/http/httptest"
	"testing"
	"time"
)

func TestAllow_BurstOk(t *testing.T) {
	l := New(100, 10)
	defer l.Stop()

	// Con capacity=10, las primeras 10 requests de la misma IP deben pasar
	ip := "10.0.0.1"
	passed := 0
	for i := 0; i < 10; i++ {
		if l.Allow(ip) {
			passed++
		}
	}
	if passed != 10 {
		t.Errorf("burst: esperados 10 pasados, obtenidos %d", passed)
	}
}

func TestAllow_ExcesoRechazado(t *testing.T) {
	l := New(100, 5)
	defer l.Stop()

	ip := "10.0.0.2"
	// Consumir toda la capacidad
	for i := 0; i < 5; i++ {
		l.Allow(ip)
	}
	// La siguiente debe ser rechazada
	if l.Allow(ip) {
		t.Error("request 6 con capacity=5 debe ser rechazada")
	}
}

func TestAllow_RecargaConTiempo(t *testing.T) {
	// rate=1000 tok/s, capacity=1 → tras 1ms se recarga ~1 token
	l := New(1000, 1)
	defer l.Stop()

	ip := "10.0.0.3"
	l.Allow(ip) // consumir el único token

	if l.Allow(ip) {
		t.Error("debe estar vacío inmediatamente después")
	}

	time.Sleep(2 * time.Millisecond) // esperar recarga

	if !l.Allow(ip) {
		t.Error("debe permitir tras recarga de token")
	}
}

func TestAllow_IPsIndependientes(t *testing.T) {
	l := New(100, 1)
	defer l.Stop()

	ip1 := "10.0.0.10"
	ip2 := "10.0.0.11"

	l.Allow(ip1) // agotar ip1

	// ip2 no debe verse afectada
	if !l.Allow(ip2) {
		t.Error("ip2 no debe verse afectada por agotamiento de ip1")
	}
}

func TestAllow_UnixSocket_SiemprePermite(t *testing.T) {
	l := New(1, 1)
	defer l.Stop()

	// IPs vacías (Unix socket) siempre deben pasar
	for i := 0; i < 10; i++ {
		if !l.Allow("") {
			t.Error("Unix socket debe siempre pasar (sin rate limit)")
		}
	}
}

func TestLen_Crece(t *testing.T) {
	l := New(100, 100)
	defer l.Stop()

	for i := 0; i < 5; i++ {
		l.Allow(fmt.Sprintf("10.0.0.%d", i))
	}
	if l.Len() != 5 {
		t.Errorf("Len debe ser 5, obtenido %d", l.Len())
	}
}

func TestExtractIP_RemoteAddr(t *testing.T) {
	r := httptest.NewRequest("POST", "/rpc", nil)
	r.RemoteAddr = "192.168.1.5:12345"
	if ip := ExtractIP(r); ip != "192.168.1.5" {
		t.Errorf("ExtractIP RemoteAddr: esperado '192.168.1.5', obtenido %q", ip)
	}
}

func TestExtractIP_XRealIP(t *testing.T) {
	r := httptest.NewRequest("POST", "/rpc", nil)
	r.Header.Set("X-Real-IP", "203.0.113.5")
	if ip := ExtractIP(r); ip != "203.0.113.5" {
		t.Errorf("ExtractIP X-Real-IP: esperado '203.0.113.5', obtenido %q", ip)
	}
}

func TestExtractIP_XRealIP_Invalida(t *testing.T) {
	// X-Real-IP con valor inválido → fallback a RemoteAddr
	r := httptest.NewRequest("POST", "/rpc", nil)
	r.RemoteAddr = "10.0.0.1:9000"
	r.Header.Set("X-Real-IP", "not-an-ip")
	if ip := ExtractIP(r); ip != "10.0.0.1" {
		t.Errorf("ExtractIP fallback: esperado '10.0.0.1', obtenido %q", ip)
	}
}
