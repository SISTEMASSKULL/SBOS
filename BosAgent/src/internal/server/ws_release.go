package server

// ws_release.go — Handlers de Release Plane y PG Auxiliar Anti-Pérdida (M-10, F6).

import "fmt"

func (s *Server) wsHandleReleaseCheck(client *Client, req *Request) {
	if s.releaseMgr == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "release manager not available")
		return
	}
	ficha, _ := req.Params["ficha"].(string)
	version, _ := req.Params["version"].(string)
	if ficha == "" {
		ficha = "*"
	}
	if version == "" {
		version = "0.0.0"
	}

	s.wsHub.Broadcast(Event{Type: EventReleaseCheck, Message: "checking for updates..."})
	releases, err := s.releaseMgr.CheckAvailable(ficha, version)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
			"updates": []interface{}{}, "offline": true, "error": err.Error(),
		}, "")
		return
	}
	if len(releases) > 0 {
		latest := releases[0]
		s.wsHub.Broadcast(Event{
			Type:    EventReleaseAvailable,
			Ficha:   latest.Ficha,
			Message: fmt.Sprintf("%s %s available (channel: %s)", latest.Ficha, latest.Version, latest.Channel),
		})
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"updates": releases, "count": len(releases), "offline": false,
	}, "")
}

func (s *Server) wsHandleReleaseList(client *Client, req *Request) {
	if s.releaseMgr == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "release manager not available")
		return
	}
	releases, err := s.releaseMgr.ListAll()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"releases": releases, "count": len(releases),
	}, "")
}

func (s *Server) wsHandlePgAuxiliarStart(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	sourcePod, _ := req.Params["source_pod"].(string)
	sourceNS, _ := req.Params["source_ns"].(string)
	if sourcePod == "" {
		sourcePod = "postgresql-0"
	}
	if sourceNS == "" {
		sourceNS = "sbos-data"
	}

	result, err := s.pgAuxSvc.Start(sourcePod, sourceNS, nil)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandlePgAuxiliarSync(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	targetPod, _ := req.Params["target_pod"].(string)
	targetNS, _ := req.Params["target_ns"].(string)
	database, _ := req.Params["database"].(string)
	if targetPod == "" {
		targetPod = "postgresql-0"
	}
	if targetNS == "" {
		targetNS = "sbos-data"
	}
	if database == "" {
		database = "postgres"
	}

	result, err := s.pgAuxSvc.Sync(targetPod, targetNS, database)
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, result, "")
}

func (s *Server) wsHandlePgAuxiliarStatus(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, s.pgAuxSvc.Status(), "")
}

func (s *Server) wsHandlePgAuxiliarCleanup(client *Client, req *Request) {
	if s.pgAuxSvc == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, "pg_auxiliar service not available")
		return
	}
	if err := s.pgAuxSvc.Cleanup(); err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, err.Error())
		return
	}
	s.wsHub.sendResponse(client, req.ID, true, map[string]bool{"cleaned": true}, "")
}
