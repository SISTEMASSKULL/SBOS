// Package grpc implementa el servidor gRPC del Ficha Engine.
// Transporte: Unix socket /run/bos/bos-grpc.sock (SBOS-050 P9).
// Interceptors §17.3: Recovery → Context → Logging.
package grpc

// server_core.go — FichaServer struct, New, ListenAndServe e interceptors (M-12, F6).

import (
	"context"
	"log/slog"
	"net"
	"os"
	"time"

	"bos/internal/domain"
	"bos/internal/ficha"
	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// FichaServer implementa pb.FichaServiceServer generado desde ficha.proto.
// Embebe UnimplementedFichaServiceServer para forward-compat (§17.1).
type FichaServer struct {
	pb.UnimplementedFichaServiceServer
	svc        *domain.FichaService
	exec       *ficha.Executor    // F11.A.4 — ejecutor de 5 fases (nil = usar legacy Orchestrator)
	discoverer *ficha.Discoverer  // F11.A.5 — descubridor de fichas (nil = usar legacy Loader)
	catalog    domain.CatalogPort // catálogo de fichas para resolver rutas (estrategia 2)
	logger     *slog.Logger
	server     *grpc.Server
}

// NewFichaServer crea el servidor gRPC con interceptors (§17.3).
// exec, discoverer y catalog son opcionales — si son nil se usa el legacy.
func NewFichaServer(svc *domain.FichaService, exec *ficha.Executor, discoverer *ficha.Discoverer, catalog domain.CatalogPort, logger *slog.Logger) *FichaServer {
	return &FichaServer{svc: svc, exec: exec, discoverer: discoverer, catalog: catalog, logger: logger}
}

// ListenAndServe inicia el servidor gRPC en el Unix socket dado.
// Bloquea hasta que el contexto se cancela.
func (s *FichaServer) ListenAndServe(ctx context.Context, socketPath string) error {
	if err := os.Remove(socketPath); err != nil && !os.IsNotExist(err) {
		return status.Errorf(codes.Internal, "grpc: limpiar socket %s: %v", socketPath, err)
	}

	s.server = grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			s.recoveryInterceptor,
			s.contextInterceptor,
			s.loggingInterceptor,
		),
		grpc.ChainStreamInterceptor(
			s.recoveryStreamInterceptor,
			s.contextStreamInterceptor,
			s.loggingStreamInterceptor,
		),
	)
	pb.RegisterFichaServiceServer(s.server, s)

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		return status.Errorf(codes.Internal, "grpc: listen unix://%s: %v", socketPath, err)
	}

	if err := os.Chmod(socketPath, 0660); err != nil {
		s.logger.Warn("grpc: chmod socket", "err", err)
	}

	s.logger.Info("gRPC FichaService iniciado", "socket", socketPath)

	go func() {
		<-ctx.Done()
		s.server.GracefulStop()
	}()

	return s.server.Serve(listener)
}

// ── Interceptors ─────────────────────────────────────────────────────

func (s *FichaServer) recoveryInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("grpc panic", "method", info.FullMethod, "panic", r)
			err = status.Error(codes.Internal, "error interno del servidor")
		}
	}()
	return handler(ctx, req)
}

// contextInterceptor extrae el ctx_id del RequestContext y lo inyecta en el
// context.Context de Go para trazabilidad extremo-a-extremo (SBOS-049, W3C Trace Context).
func (s *FichaServer) contextInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	type hasCtx interface {
		GetCtx() *pb.RequestContext
	}
	if hc, ok := req.(hasCtx); ok {
		if reqCtx := hc.GetCtx(); reqCtx != nil {
			if reqCtx.CtxId != "" && reqCtx.CtxId != ctxIDStub() {
				ctx = context.WithValue(ctx, ctxKeyCtxID{}, reqCtx.CtxId)
			}
			if reqCtx.CorrelationId != "" {
				ctx = context.WithValue(ctx, ctxKeyCorrelationID{}, reqCtx.CorrelationId)
			}
		}
	}
	return handler(ctx, req)
}

// ctxKeyCtxID es la clave de contexto para el ctx_id (SBOS-049).
type ctxKeyCtxID struct{}

// ctxKeyCorrelationID es la clave de contexto para el traceparent W3C.
type ctxKeyCorrelationID struct{}

func (s *FichaServer) loggingInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	duration := time.Since(start)
	if err != nil {
		s.logger.Warn("grpc call failed", "method", info.FullMethod, "duration", duration, "err", err)
	} else {
		s.logger.Debug("grpc call ok", "method", info.FullMethod, "duration", duration)
	}
	return resp, err
}

func (s *FichaServer) recoveryStreamInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("grpc stream panic", "method", info.FullMethod, "panic", r)
		}
	}()
	return handler(srv, ss)
}

// contextStreamInterceptor extrae el ctx_id del stream gRPC para trazabilidad.
func (s *FichaServer) contextStreamInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	// TODO(F5): leer metadata del stream context cuando Context Plane esté operativo.
	return handler(srv, ss)
}

func (s *FichaServer) loggingStreamInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	s.logger.Debug("grpc stream started", "method", info.FullMethod)
	return handler(srv, ss)
}

// ctxIDStub retorna un ctx_id placeholder hasta que el Context Plane (F5) esté operativo.
func ctxIDStub() string {
	return "00000000-0000-4000-8000-000000000000"
}
