package grpc

// server_helpers.go — Funciones puras: domainErrToGRPC, mappers, defaultAutoCapabilities (M-12, F6).

import (
	"errors"

	"bos/internal/domain"
	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/durationpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// domainErrToGRPC mapea errores de dominio a códigos gRPC (§12.6).
func domainErrToGRPC(err error) error {
	if err == nil {
		return nil
	}
	msg := err.Error()
	switch {
	case isDomainErr(err, domain.ErrFichaNotFound):
		return status.Error(codes.NotFound, msg)
	case isDomainErr(err, domain.ErrFichaIDRequired),
		isDomainErr(err, domain.ErrVersionRequired),
		isDomainErr(err, domain.ErrCommandRequired),
		isDomainErr(err, domain.ErrCommandInvalid),
		isDomainErr(err, domain.ErrReplicasInvalidas):
		return status.Error(codes.InvalidArgument, msg)
	case isDomainErr(err, domain.ErrBootstrapInProgress),
		isDomainErr(err, domain.ErrFichaAlreadyPaused),
		isDomainErr(err, domain.ErrFichaNotPaused):
		return status.Error(codes.FailedPrecondition, msg)
	case isDomainErr(err, domain.ErrInstallerUnavailable),
		isDomainErr(err, domain.ErrStateUnavailable):
		return status.Error(codes.Unavailable, msg)
	case isDomainErr(err, domain.ErrSagaFailed):
		return status.Error(codes.Internal, msg)
	default:
		return status.Error(codes.Internal, msg)
	}
}

// isDomainErr verifica si err coincide con target usando errors.Is() (ORQUESTA-043 §2).
func isDomainErr(err error, target error) bool {
	return err != nil && errors.Is(err, target)
}

// mapSagaOutcome convierte domain.SagaOutcome a proto.
func mapSagaOutcome(outcome *domain.SagaOutcome, cmd pb.SagaCommand) *pb.SagaOutcome {
	if outcome == nil {
		return nil
	}
	return &pb.SagaOutcome{
		FichaId:   outcome.FichaID,
		Command:   cmd,
		Success:   outcome.Success,
		ExitCode:  int32(outcome.ExitCode),
		Duration:  durationpb.New(outcome.Duration),
		StepCount: int32(outcome.StepCount),
		Steps:     make([]*pb.SagaStep, 0),
	}
}

// mapFicha convierte la info de una ficha del state manager a proto.
func mapFicha(f *domain.FichaInfo) *pb.Ficha {
	if f == nil {
		return nil
	}
	return &pb.Ficha{
		Id:           f.ID,
		Version:      f.Version,
		State:        f.State,
		Server:       f.Server,
		HealthStatus: f.Health,
		InstalledAt:  timestamppb.New(f.InstalledAt),
		UpdatedAt:    timestamppb.New(f.UpdatedAt),
	}
}

// mapDriftItems convierte []domain.DriftItem a proto.
func mapDriftItems(items []domain.DriftItem) []*pb.DriftItem {
	result := make([]*pb.DriftItem, len(items))
	for i, item := range items {
		result[i] = &pb.DriftItem{
			Path:     item.Path,
			Declared: item.Declared,
			Actual:   item.Actual,
		}
	}
	return result
}

// defaultAutoCapabilities retorna las capacidades automáticas del stack SBOS.
func defaultAutoCapabilities() []string {
	return []string{
		"SSO (Keycloak)", "ctx_id (OTel Baggage)",
		"mTLS (Linkerd)", "métricas (Prometheus)", "secretos (Vault)",
	}
}
