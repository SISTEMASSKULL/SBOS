package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"bos/internal/state"
)

// Snapshot captures the state of a ficha at a point in time.
type Snapshot struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	FichaID   string    `json:"ficha_id"`
	State     string    `json:"state"`
	Version   string    `json:"version"`
}

const snapshotsDir = "/etc/bos/catalog/snapshots"

// CreateSnapshot saves the current state of a ficha as a named snapshot.
func CreateSnapshot(mgr *state.Manager, fichaID string) (*Snapshot, error) {
	st, err := mgr.Read()
	if err != nil {
		return nil, fmt.Errorf("catalog: read state: %w", err)
	}

	ficha, ok := st.Fichas[fichaID]
	if !ok {
		return nil, fmt.Errorf("catalog: ficha %s not found", fichaID)
	}

	snap := &Snapshot{
		ID:        fmt.Sprintf("%s-%d", sanitizeSnapName(fichaID), time.Now().Unix()),
		Timestamp: time.Now().UTC(),
		FichaID:   fichaID,
		State:     string(ficha.State),
		Version:   ficha.Version,
	}

	if err := os.MkdirAll(snapshotsDir, 0755); err != nil {
		return nil, fmt.Errorf("catalog: mkdir snapshots: %w", err)
	}

	data, err := json.MarshalIndent(snap, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("catalog: marshal snapshot: %w", err)
	}

	path := filepath.Join(snapshotsDir, snap.ID+".json")
	if err := os.WriteFile(path, data, 0644); err != nil {
		return nil, fmt.Errorf("catalog: write snapshot: %w", err)
	}

	return snap, nil
}

// ListSnapshots returns all snapshots, optionally filtered by ficha ID.
// Pass empty string to list all.
func ListSnapshots(fichaID string) ([]Snapshot, error) {
	entries, err := os.ReadDir(snapshotsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("catalog: read snapshots dir: %w", err)
	}

	var snapshots []Snapshot
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(snapshotsDir, entry.Name()))
		if err != nil {
			continue
		}
		var snap Snapshot
		if err := json.Unmarshal(data, &snap); err != nil {
			continue
		}
		if fichaID == "" || snap.FichaID == fichaID {
			snapshots = append(snapshots, snap)
		}
	}

	sort.Slice(snapshots, func(i, j int) bool {
		return snapshots[i].Timestamp.After(snapshots[j].Timestamp)
	})
	return snapshots, nil
}

func sanitizeSnapName(name string) string {
	return strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			return r
		}
		return '-'
	}, name)
}
