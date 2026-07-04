package grpc

// server_ops.go — Handlers de consulta: Pause, Resume, Scale, Status, List, Describe, Plan, Diff, Validate (M-12, F6).

import (
	"context"

	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (s *FichaServer) Pause(ctx context.Context, req *pb.PauseRequest) (*pb.PauseResponse, error) {
	outcome, err := s.svc.Pause(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.PauseResponse{
		FichaId:   outcome.FichaID,
		PrevState: "INSTALADA", // TODO: obtener del state manager
		Success:   outcome.Success,
	}, nil
}

func (s *FichaServer) Resume(ctx context.Context, req *pb.ResumeRequest) (*pb.ResumeResponse, error) {
	outcome, err := s.svc.Resume(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.ResumeResponse{
		FichaId:  outcome.FichaID,
		NewState: "INSTALADA", // TODO: obtener del state manager
		Success:  outcome.Success,
	}, nil
}

func (s *FichaServer) Scale(ctx context.Context, req *pb.ScaleRequest) (*pb.ScaleResponse, error) {
	return nil, status.Error(codes.Unimplemented, "scale requiere acceso K8s (F9)")
}

func (s *FichaServer) Status(ctx context.Context, req *pb.StatusRequest) (*pb.StatusResponse, error) {
	single, all, err := s.svc.Status(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	if single != nil {
		return &pb.StatusResponse{
			Result: &pb.StatusResponse_Single{Single: mapFicha(single)},
		}, nil
	}
	fichas := make([]*pb.Ficha, 0, len(all))
	for _, f := range all {
		fichas = append(fichas, mapFicha(f))
	}
	return &pb.StatusResponse{
		Result: &pb.StatusResponse_All{
			All: &pb.FichaList{Fichas: fichas, Total: int32(len(fichas))},
		},
	}, nil
}

func (s *FichaServer) List(ctx context.Context, req *pb.ListRequest) (*pb.ListResponse, error) {
	details := s.svc.List()
	fichas := make([]*pb.Ficha, 0, len(details))
	for _, d := range details {
		fichas = append(fichas, &pb.Ficha{
			Id:             d.ID,
			Version:        d.Version,
			Server:         d.Server,
			AutoInstall:    d.AutoInstall,
			ExecutionOrder: int32(d.ExecutionOrder),
			Dependencies:   d.Dependencies,
		})
	}
	return &pb.ListResponse{Fichas: fichas, Total: int32(len(fichas))}, nil
}

func (s *FichaServer) Describe(ctx context.Context, req *pb.DescribeRequest) (*pb.DescribeResponse, error) {
	single, _, err := s.svc.Status(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	if single == nil {
		return nil, status.Error(codes.NotFound, "ficha no encontrada: "+req.FichaId)
	}
	return &pb.DescribeResponse{
		Ficha:            mapFicha(single),
		Versions:         nil, // TODO: obtener del plugin.Loader
		AutoCapabilities: defaultAutoCapabilities(),
	}, nil
}

func (s *FichaServer) Plan(ctx context.Context, req *pb.PlanRequest) (*pb.PlanResponse, error) {
	result, err := s.svc.Plan()
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	waves := make([]*pb.Wave, len(result.Waves))
	for i, w := range result.Waves {
		waves[i] = &pb.Wave{Level: int32(i), FichaIds: w}
	}
	return &pb.PlanResponse{
		Order:     result.Order,
		Waves:     waves,
		Total:     int32(result.Total),
		HasCycles: result.HasCycles,
	}, nil
}

func (s *FichaServer) Diff(ctx context.Context, req *pb.DiffRequest) (*pb.DiffResponse, error) {
	single, summary, err := s.svc.Diff(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	if single != nil {
		return &pb.DiffResponse{
			Result: &pb.DiffResponse_Single{Single: &pb.DiffResult{
				FichaId:  single.FichaID,
				HasDrift: single.HasDrift,
				Items:    mapDriftItems(single.Items),
			}},
		}, nil
	}
	return &pb.DiffResponse{
		Result: &pb.DiffResponse_Summary{Summary: &pb.DiffSummary{
			TotalFichas:   int32(summary.TotalFichas),
			DriftedFichas: int32(summary.DriftedFichas),
			OkFichas:      int32(summary.OkFichas),
		}},
	}, nil
}

func (s *FichaServer) Validate(ctx context.Context, req *pb.ValidateRequest) (*pb.ValidateResponse, error) {
	results, err := s.svc.Validate(req.FichaId)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	pbResults := make([]*pb.ValidationResult, len(results))
	for i, r := range results {
		errs := make([]*pb.ValidationError, len(r.Errors))
		for j, e := range r.Errors {
			errs[j] = &pb.ValidationError{Field: e.Field, Message: e.Message, Value: e.Value}
		}
		pbResults[i] = &pb.ValidationResult{FichaId: r.FichaID, Valid: r.Valid, Errors: errs}
	}
	validCount := int32(0)
	for _, r := range results {
		if r.Valid {
			validCount++
		}
	}
	return &pb.ValidateResponse{
		Results:     pbResults,
		TotalFichas: int32(len(results)),
		ValidFichas: validCount,
	}, nil
}
