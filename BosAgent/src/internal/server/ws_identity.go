package server

// ws_identity.go — Handlers de identidad WebSocket: whoami, list, set-role, revoke (M-10, F6).

func (s *Server) handleWSIdentityWhoami(client *Client) {
	if client.User == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityWhoami,
			Message: "unauthenticated — no BOS-User header",
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: EventIdentityWhoami,
		User: client.User,
		Role: client.Role,
	})
}

func (s *Server) handleWSIdentityListUsers(client *Client) {
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityListUsers,
			Message: "identity provider not available",
		})
		return
	}
	users, err := client.identity.ListUsers()
	if err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityListUsers,
			Message: err.Error(),
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: EventIdentityListUsers,
		Data: users,
	})
}

func (s *Server) handleWSIdentityListRoles(client *Client) {
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityListRoles,
			Message: "identity provider not available",
		})
		return
	}
	roles, err := client.identity.ListRoles()
	if err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityListRoles,
			Message: err.Error(),
		})
		return
	}
	s.wsHub.BroadcastTo(client, Event{
		Type: EventIdentityListRoles,
		Data: roles,
	})
}

func (s *Server) handleWSIdentitySetRole(client *Client, event Event) {
	if client.rbac != nil {
		if err := client.rbac.CanExecute(client.User, "identity set-role"); err != nil {
			s.wsHub.BroadcastTo(client, Event{
				Type:    EventIdentitySetRole,
				Message: "access denied: " + err.Error(),
			})
			return
		}
	}
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentitySetRole,
			Message: "identity provider not available",
		})
		return
	}

	targetUser := event.User
	targetRole := event.Role
	if m, ok := event.Data.(map[string]interface{}); ok {
		if u, _ := m["user"].(string); u != "" {
			targetUser = u
		}
		if r, _ := m["role"].(string); r != "" {
			targetRole = r
		}
	}
	if targetUser == "" || targetRole == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentitySetRole,
			Message: "user and role required",
		})
		return
	}

	if err := client.identity.SetRole(targetUser, targetRole); err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentitySetRole,
			Message: err.Error(),
		})
		return
	}

	s.wsHub.BroadcastTo(client, Event{
		Type:    EventIdentitySetRole,
		User:    targetUser,
		Role:    targetRole,
		Message: "role assigned",
	})
	s.wsHub.Broadcast(Event{
		Type: EventIdentityChanged,
		User: targetUser,
		Role: targetRole,
	})
}

func (s *Server) handleWSIdentityRevoke(client *Client, event Event) {
	if client.rbac != nil {
		if err := client.rbac.CanExecute(client.User, "identity revoke"); err != nil {
			s.wsHub.BroadcastTo(client, Event{
				Type:    EventIdentityRevoke,
				Message: "access denied: " + err.Error(),
			})
			return
		}
	}
	if client.identity == nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityRevoke,
			Message: "identity provider not available",
		})
		return
	}

	targetUser := event.User
	if targetUser == "" {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityRevoke,
			Message: "user required",
		})
		return
	}

	if err := client.identity.RemoveUser(targetUser); err != nil {
		s.wsHub.BroadcastTo(client, Event{
			Type:    EventIdentityRevoke,
			Message: err.Error(),
		})
		return
	}

	s.wsHub.BroadcastTo(client, Event{
		Type:    EventIdentityRevoke,
		User:    targetUser,
		Message: "user revoked",
	})
	s.wsHub.Broadcast(Event{
		Type: EventIdentityChanged,
		User: targetUser,
	})
}
