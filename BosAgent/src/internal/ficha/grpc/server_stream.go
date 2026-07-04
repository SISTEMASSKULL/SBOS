package grpc

// server_stream.go — Handlers de streaming y administración: Rescan, ResetState, Watch, GetLogs (M-12, F6).

import (
	"context"
	"fmt"
	"time"

	pb "bos/proto/bos/ficha/v1"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (s *FichaServer) Rescan(ctx context.Context, req *pb.RescanRequest) (*pb.RescanResponse, error) {
	if s.discoverer != nil {
		result, err := s.discoverer.Discover()
		if err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
		added := make([]string, 0)
		for _, f := range result.Fichas {
			if f.IsNew {
				added = append(added, f.ID)
			}
		}
		return &pb.RescanResponse{
			Discovered: int32(result.New),
			Total:      int32(result.Total),
			Added:      added,
		}, nil
	}

	result, err := s.svc.Rescan()
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.RescanResponse{
		Discovered: int32(result.Discovered),
		Total:      int32(result.Total),
		Added:      result.Added,
	}, nil
}

func (s *FichaServer) ResetState(ctx context.Context, req *pb.ResetStateRequest) (*pb.ResetStateResponse, error) {
	outcome, err := s.svc.ResetState(req.FichaId, req.TargetState)
	if err != nil {
		return nil, domainErrToGRPC(err)
	}
	return &pb.ResetStateResponse{
		FichaId:  outcome.FichaID,
		NewState: req.TargetState,
		Success:  outcome.Success,
	}, nil
}

// Watch transmite eventos de ficha en tiempo real (server-streaming).
// TODO(F11): implementar bus de eventos real usando canales Go.
func (s *FichaServer) Watch(req *pb.WatchRequest, stream pb.FichaService_WatchServer) error {
	s.logger.Debug("Watch iniciado", "ficha_id", req.FichaId)

	heartbeat := &pb.FichaEvent{
		EventId:   fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		Type:      pb.FichaEventType_FICHA_EVENT_TYPE_HEARTBEAT,
		FichaId:   req.FichaId,
		Timestamp: timestamppb.Now(),
		Payload: &pb.FichaEvent_Heartbeat{
			Heartbeat: &pb.HeartbeatPayload{
				DaemonVersion: "bos-1.0",
				UptimeSeconds: 0,
				MemoryMb:      0,
			},
		},
	}
	if err := stream.Send(heartbeat); err != nil {
		return err
	}

	select {
	case <-stream.Context().Done():
		s.logger.Debug("Watch finalizado", "ficha_id", req.FichaId)
		return stream.Context().Err()
	}
}

// GetLogs transmite líneas de log de ficha en tiempo real (server-streaming).
// TODO(F11.F.2): implementar lectura real de /var/log/bos/fichas/<name>.log
func (s *FichaServer) GetLogs(req *pb.GetLogsRequest, stream pb.FichaService_GetLogsServer) error {
	s.logger.Debug("GetLogs iniciado", "ficha_id", req.FichaId)
	select {
	case <-stream.Context().Done():
		return stream.Context().Err()
	}
}

