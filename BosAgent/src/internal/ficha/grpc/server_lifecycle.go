package grpc

// server_lifecycle.go — Install, Update, Repair, Remove, Probe + infraestructura de ciclo de vida (M-12, F6).

import (
	"context"
	"fmt"

	"bos/internal/domain"
	"bos/internal/ficha"
	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/durationpb"
)

func (s *FichaServer) Install(ctx context.Context, req *pb.InstallRequest) (*pb.InstallResponse, error) {
	if s.exec != nil {
		return s.installWithPhases(req)
	}
	outcome, err := s.svc.Install(req.FichaId, req.Version)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.InstallResponse{Outcome: mapSagaOutcome(outcome, pb.SagaCommand_SAGA_COMMAND_INSTALL)}, nil
}

// installWithPhases ejecuta la instalación usando el pipeline de 5 fases (F11.A.4).
func (s *FichaServer) installWithPhases(req *pb.InstallRequest) (*pb.InstallResponse, error) {
	taskDir := s.resolveTaskDir(req.FichaId)
	if taskDir == "" {
		return nil, status.Error(codes.NotFound, "directorio de ficha no encontrado: "+req.FichaId)
	}
	result, err := s.exec.Execute(req.FichaId, "install", taskDir)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	return &pb.InstallResponse{
		Outcome: &pb.SagaOutcome{
			FichaId:   result.FichaID,
			Command:   pb.SagaCommand_SAGA_COMMAND_INSTALL,
			Success:   result.Success,
			Duration:  durationpb.New(result.Duration),
			StepCount: int32(len(result.Phases)),
		},
	}, nil
}

// resolveTaskDir obtiene el directorio de trabajo de una ficha con dos estrategias:
//  1. Discoverer (F11.A.5) — indexado en el escaneo inicial de servers/
//  2. CatalogPort — consulta el catálogo de plugins (FichaManifest.Path)
func (s *FichaServer) resolveTaskDir(fichaID string) string {
	if s.discoverer != nil {
		if path, ok := s.discoverer.GetKnownPaths()[fichaID]; ok && path != "" {
			return path
		}
	}
	if s.catalog != nil {
		if mf, ok := s.catalog.Get(fichaID); ok && mf != nil && mf.Path != "" {
			return mf.Path
		}
	}
	return ""
}

// WireLifecycle conecta el Executor y el Discoverer al Lifecycle del dominio.
// Debe llamarse después de NewFichaServer y antes de ListenAndServe.
func (s *FichaServer) WireLifecycle(lc *ficha.Lifecycle) {
	if s.exec != nil && s.discoverer != nil {
		lc.SetExecutor(s.exec, s.resolveTaskDir)
		s.logger.Info("lifecycle cableado con executor real")
	} else {
		s.logger.Warn("lifecycle sin executor — usando simulación para rollback/cleanup/repair")
	}
}

// InitDiscoverer ejecuta un descubrimiento inicial y popula el resolver de rutas.
func (s *FichaServer) InitDiscoverer(serversPath string) error {
	if s.discoverer == nil {
		s.discoverer = ficha.NewDiscoverer(serversPath, s.logger)
	}
	_, err := s.discoverer.Discover()
	if err != nil {
		return fmt.Errorf("init discoverer: %w", err)
	}
	s.logger.Info("discoverer inicializado", "path", serversPath)
	return nil
}

// execOrFallback intenta ejecutar la operación vía el Executor de 5 fases (F11.A.4).
// Si no hay executor o no encuentra el taskDir, delega en el FichaService legacy.
func (s *FichaServer) execOrFallback(fichaID, op string, cmd pb.SagaCommand,
	legacyFn func(string) (*domain.SagaOutcome, error)) (*pb.SagaOutcome, error) {

	if s.exec != nil {
		if taskDir := s.resolveTaskDir(fichaID); taskDir != "" {
			result, err := s.exec.Execute(fichaID, op, taskDir)
			if err != nil {
				return nil, status.Error(codes.Internal, err.Error())
			}
			return &pb.SagaOutcome{
				FichaId:   result.FichaID,
				Command:   cmd,
				Success:   result.Success,
				Duration:  durationpb.New(result.Duration),
				StepCount: int32(len(result.Phases)),
			}, nil
		}
	}

	outcome, err := legacyFn(fichaID)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return mapSagaOutcome(outcome, cmd), nil
}

func (s *FichaServer) Update(ctx context.Context, req *pb.UpdateRequest) (*pb.UpdateResponse, error) {
	outcome, err := s.execOrFallback(req.FichaId, "update", pb.SagaCommand_SAGA_COMMAND_UPDATE,
		func(fid string) (*domain.SagaOutcome, error) { return s.svc.Update(fid, req.Version) })
	if err != nil {
		return nil, err
	}
	return &pb.UpdateResponse{Outcome: outcome}, nil
}

func (s *FichaServer) Repair(ctx context.Context, req *pb.RepairRequest) (*pb.RepairResponse, error) {
	outcome, err := s.execOrFallback(req.FichaId, "repair", pb.SagaCommand_SAGA_COMMAND_REPAIR, s.svc.Repair)
	if err != nil {
		return nil, err
	}
	return &pb.RepairResponse{Outcome: outcome}, nil
}

func (s *FichaServer) Remove(ctx context.Context, req *pb.RemoveRequest) (*pb.RemoveResponse, error) {
	outcome, err := s.execOrFallback(req.FichaId, "remove", pb.SagaCommand_SAGA_COMMAND_REMOVE, s.svc.Remove)
	if err != nil {
		return nil, err
	}
	return &pb.RemoveResponse{Outcome: outcome}, nil
}

func (s *FichaServer) Probe(ctx context.Context, req *pb.ProbeRequest) (*pb.ProbeResponse, error) {
	outcome, err := s.svc.Probe(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.ProbeResponse{Outcome: mapSagaOutcome(outcome, pb.SagaCommand_SAGA_COMMAND_PROBE)}, nil
}
