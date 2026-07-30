// Package ratelimit — rate limiter token bucket por IP (NRS-08).
//
// Implementa el algoritmo token bucket para limitar solicitudes JSON-RPC al daemon BOS.
// El límite especificado en el manual es: 100 solicitudes/segundo por IP.
//
// Thread-safe, sin dependencias externas. Las entradas inactivas se limpian
// cada 5 minutos para evitar fugas de memoria con IPs efímeras.
//
// Referencia: 1.04_MANUAL-IAM-INSTALLER-SEGURIDAD.md §NRS-08
package ratelimit

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	cleanupInterval = 5 * time.Minute
	idleTimeout     = 10 * time.Minute
)

// bucket es el estado del token bucket para una IP.
type bucket struct {
	mu       sync.Mutex
	tokens   float64
	lastSeen time.Time
}

// consume intenta consumir un token. Retorna true si se concede el request.
func (b *bucket) consume(rate, capacity float64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(b.lastSeen).Seconds()
	b.tokens += elapsed * rate
	if b.tokens > capacity {
		b.tokens = capacity
	}
	b.lastSeen = now

	if b.tokens >= 1.0 {
		b.tokens -= 1.0
		return true
	}
	return false
}

// IPLimiter limita solicitudes por IP usando el algoritmo token bucket.
type IPLimiter struct {
	mu       sync.Mutex
	buckets  map[string]*bucket
	rate     float64 // tokens por segundo
	capacity float64 // capacidad máxima (burst)
	stopCh   chan struct{}
}

// New crea un IPLimiter con los parámetros dados.
//   - ratePerSecond: tokens a reponer por segundo (ej. 100.0)
//   - capacity: capacidad de burst (ej. 100.0)
func New(ratePerSecond, capacity float64) *IPLimiter {
	l := &IPLimiter{
		buckets:  make(map[string]*bucket),
		rate:     ratePerSecond,
		capacity: capacity,
		stopCh:   make(chan struct{}),
	}
	go l.cleanup()
	return l
}

// Allow retorna true si la solicitud de ip está permitida.
// Thread-safe. Si ip está vacío, siempre permite (modo permisivo para Unix sockets).
func (l *IPLimiter) Allow(ip string) bool {
	if ip == "" || ip == "@" {
		return true // Unix socket: sin IP, sin límite (solo daemons locales)
	}

	l.mu.Lock()
	b, ok := l.buckets[ip]
	if !ok {
		b = &bucket{tokens: l.capacity, lastSeen: time.Now()}
		l.buckets[ip] = b
	}
	l.mu.Unlock()

	return b.consume(l.rate, l.capacity)
}

// Stop detiene la goroutine de limpieza.
func (l *IPLimiter) Stop() {
	close(l.stopCh)
}

// Len retorna el número de IPs actualmente rastreadas.
func (l *IPLimiter) Len() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.buckets)
}

// cleanup elimina buckets inactivos para evitar fugas de memoria.
func (l *IPLimiter) cleanup() {
	ticker := time.NewTicker(cleanupInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			cutoff := time.Now().Add(-idleTimeout)
			l.mu.Lock()
			for ip, b := range l.buckets {
				b.mu.Lock()
				idle := b.lastSeen.Before(cutoff)
				b.mu.Unlock()
				if idle {
					delete(l.buckets, ip)
				}
			}
			l.mu.Unlock()
		case <-l.stopCh:
			return
		}
	}
}

// ExtractIP obtiene la IP del cliente desde una petición HTTP.
// Respeta X-Real-IP (Kong/nginx) primero, luego RemoteAddr.
func ExtractIP(r *http.Request) string {
	// Kong injecta X-Real-IP con la IP del cliente final
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		if net.ParseIP(strings.TrimSpace(ip)) != nil {
			return strings.TrimSpace(ip)
		}
	}
	// Unix socket: RemoteAddr es "@" o vacío
	if r.RemoteAddr == "" || r.RemoteAddr == "@" {
		return ""
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
