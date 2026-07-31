package portman_test

import (
	"testing"
	"time"

	"bos/internal/portman"
)

// ── Mock Kardex para tests sin BD ─────────────────────────────────────────

type mockKardex struct {
	rows []portman.KardexRow
}

func (m *mockKardex) ExistsActive(port int, portType, namespace string) (bool, error) {
	for _, r := range m.rows {
		if r.Port == port && r.PortType == portType && r.Namespace == namespace && r.Status == "assigned" {
			return true, nil
		}
	}
	return false, nil
}

func (m *mockKardex) Insert(row portman.KardexRow) error {
	row.PortID = time.Now().String()
	row.AssignedAt = time.Now()
	m.rows = append(m.rows, row)
	return nil
}

func (m *mockKardex) SetStatus(portID, status string, releasedAt *time.Time) error {
	for i := range m.rows {
		if m.rows[i].PortID == portID {
			m.rows[i].Status = status
			m.rows[i].ReleasedAt = releasedAt
			return nil
		}
	}
	return nil
}

func (m *mockKardex) ListByFicha(fichaID string) ([]portman.KardexRow, error) {
	var result []portman.KardexRow
	for _, r := range m.rows {
		if r.FichaID == fichaID {
			result = append(result, r)
		}
	}
	return result, nil
}

func (m *mockKardex) ListAll(limit int) ([]portman.KardexRow, error) {
	if limit <= 0 || limit >= len(m.rows) {
		return m.rows, nil
	}
	return m.rows[:limit], nil
}

func (m *mockKardex) GetByPort(port int, portType, namespace string) (*portman.KardexRow, error) {
	for _, r := range m.rows {
		if r.Port == port && r.PortType == portType && r.Namespace == namespace && r.Status == "assigned" {
			cp := r
			return &cp, nil
		}
	}
	return nil, nil
}

func (m *mockKardex) Close() error { return nil }

// ── Tests ─────────────────────────────────────────────────────────────────

func TestIsReserved(t *testing.T) {
	cases := []struct {
		port     int
		expected bool
	}{
		{80, true},    // IANA well-known
		{443, true},   // IANA well-known
		{9400, true},  // bos-daemon-rpc SBOS-050
		{5432, true},  // postgresql
		{20000, false}, // libre (base S00 sin ficha aún)
		{25000, false}, // libre
	}
	for _, c := range cases {
		reserved, reason := portman.IsReserved(c.port)
		if reserved != c.expected {
			t.Errorf("puerto %d: esperado reserved=%v, obtenido=%v (razón: %s)",
				c.port, c.expected, reserved, reason)
		}
	}
}

func TestAlgorithmAAssign(t *testing.T) {
	k := &mockKardex{}
	mgr := portman.New(k)

	req := portman.PortRequest{
		FichaID:       "postgresql",
		FichaIndex:    0,
		LogicalServer: "S00",
		PortTypes:     []portman.PortType{portman.PortTypeK8sClusterIP},
		Namespace:     "sbos",
		ServiceName:   "postgresql-main",
		Transport:     portman.TransportTCP,
		AssignedBy:    "bos-installer",
		CtxID:         "ctx-test-001",
	}

	result, err := mgr.Assign(req)
	if err != nil {
		t.Fatalf("Assign falló: %v", err)
	}
	if result.NeedsHITL {
		t.Fatalf("Assign no debería requerir HITL: %s", result.HITLReason)
	}
	if len(result.Assignments) != 1 {
		t.Fatalf("esperado 1 asignación, obtenido %d", len(result.Assignments))
	}

	a := result.Assignments[0]
	// BASE_S00=20000 + (0×10) + 0 = 20000
	if a.Port != 20000 {
		t.Errorf("puerto esperado 20000, obtenido %d", a.Port)
	}
	if a.Algorithm != "A" {
		t.Errorf("algoritmo esperado A, obtenido %s", a.Algorithm)
	}
}

func TestConflictResolutionN2(t *testing.T) {
	// Precargamos el puerto 20000 como asignado para forzar N2
	k := &mockKardex{
		rows: []portman.KardexRow{
			{
				PortID: "existing-1", Port: 20000, PortType: "K8S_CLUSTER_IP",
				Namespace: "sbos", Status: "assigned",
			},
		},
	}
	mgr := portman.New(k)

	req := portman.PortRequest{
		FichaID:       "postgresql",
		FichaIndex:    0,
		LogicalServer: "S00",
		PortTypes:     []portman.PortType{portman.PortTypeK8sClusterIP},
		Namespace:     "sbos",
		Transport:     portman.TransportTCP,
		AssignedBy:    "bos-installer",
		CtxID:         "ctx-test-002",
	}

	result, err := mgr.Assign(req)
	if err != nil {
		t.Fatalf("Assign con conflicto N2 falló: %v", err)
	}
	if result.NeedsHITL {
		t.Fatalf("No debería requerir HITL en N2")
	}
	if len(result.Assignments) != 1 {
		t.Fatalf("esperado 1 asignación, obtenido %d", len(result.Assignments))
	}

	a := result.Assignments[0]
	// N2 debe asignar 20000+10=20010 o similar
	if a.Port == 20000 {
		t.Errorf("N2 debió evitar el puerto 20000 que ya estaba ocupado")
	}
	t.Logf("N2 asignó puerto %d con algoritmo %s", a.Port, a.Algorithm)
}

func TestRelease(t *testing.T) {
	k := &mockKardex{
		rows: []portman.KardexRow{
			{PortID: "p1", FichaID: "redis", Port: 20010, Status: "assigned"},
			{PortID: "p2", FichaID: "redis", Port: 20011, Status: "assigned"},
		},
	}
	mgr := portman.New(k)

	released, err := mgr.Release("redis", "ctx-test-003")
	if err != nil {
		t.Fatalf("Release falló: %v", err)
	}
	if released != 2 {
		t.Errorf("esperado 2 puertos liberados, obtenido %d", released)
	}

	// Verificar que los puertos quedan como released en el mock
	rows, _ := k.ListByFicha("redis")
	for _, r := range rows {
		if r.Status != "released" {
			t.Errorf("puerto %d debería ser 'released', es %s", r.Port, r.Status)
		}
	}
}

func TestCheck(t *testing.T) {
	k := &mockKardex{}
	mgr := portman.New(k)

	// Puerto libre
	res, err := mgr.Check(20000, portman.PortTypeK8sClusterIP, "sbos")
	if err != nil {
		t.Fatalf("Check falló: %v", err)
	}
	if !res.Available {
		t.Errorf("puerto 20000 debería estar disponible: %v", res.Conflicts)
	}

	// Puerto reservado IANA
	res, err = mgr.Check(80, portman.PortTypeHostPhysical, "sbos")
	if err != nil {
		t.Fatalf("Check falló: %v", err)
	}
	if res.Available {
		t.Errorf("puerto 80 (IANA) debería estar no disponible")
	}
}

func TestExport(t *testing.T) {
	k := &mockKardex{
		rows: []portman.KardexRow{
			{
				Port: 20000, PortType: "K8S_CLUSTER_IP", FichaID: "postgresql",
				LogicalServer: "S00", Namespace: "sbos", ServiceName: "postgresql-main",
				Status: "assigned", Algorithm: "A", AssignedAt: time.Now(),
			},
		},
	}
	mgr := portman.New(k)

	md, err := mgr.Export(10)
	if err != nil {
		t.Fatalf("Export falló: %v", err)
	}
	if md == "" {
		t.Error("Export retornó cadena vacía")
	}
	t.Logf("Export:\n%s", md)
}
