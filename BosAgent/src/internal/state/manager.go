// Package state implements STATE_MANAGER — the sole writer of .sbos_state.json.
// Principle P8: No other component may write to the state file.
// Uses fcntl(F_WRLCK) for exclusive file locking across processes (ADR-021).
package state

// manager.go — NewManager, Read y capa I/O del archivo de estado (M-11, F6).

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"syscall"
	"time"
)

// NewManager abre (o crea) el archivo de estado con flock exclusivo.
// Recuperación 3 niveles: archivo principal → .bak → vacío (P8, ISO 27001 A.8.15).
func NewManager(path string) (*Manager, error) {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0600)
	if err != nil {
		return nil, fmt.Errorf("state: open %s: %w", path, err)
	}

	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return nil, fmt.Errorf("state: flock %s: %w", path, err)
	}

	m := &Manager{path: path, file: f, Recovery: RecoveryNormal}

	info, _ := f.Stat()
	if info.Size() == 0 {
		if err := m.initEmpty(); err != nil {
			f.Close()
			return nil, err
		}
		return m, nil
	}

	// Nivel 1: validar JSON del archivo principal.
	if err := m.validate(); err != nil {
		m.file.Close()
		bakPath := path + ".bak"
		if bakData, bakErr := os.ReadFile(bakPath); bakErr == nil {
			// Nivel 2: restaurar desde .bak.
			f2, err := os.OpenFile(path, os.O_RDWR|os.O_TRUNC, 0600)
			if err != nil {
				return nil, fmt.Errorf("state: reopen for backup restore: %w", err)
			}
			if _, err := f2.Write(bakData); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: write backup: %w", err)
			}
			if err := f2.Sync(); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: sync backup: %w", err)
			}
			if err := syscall.Flock(int(f2.Fd()), syscall.LOCK_EX); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: flock after backup restore: %w", err)
			}
			m.file = f2
			m.Recovery = RecoveryBackup
		} else {
			// Nivel 3: reconstruir vacío.
			f2, err := os.OpenFile(path, os.O_RDWR|os.O_TRUNC, 0600)
			if err != nil {
				return nil, fmt.Errorf("state: reopen for rebuild: %w", err)
			}
			if err := syscall.Flock(int(f2.Fd()), syscall.LOCK_EX); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: flock for rebuild: %w", err)
			}
			m.file = f2
			if err := m.initEmpty(); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: rebuild empty: %w", err)
			}
			m.Recovery = RecoveryRebuilt
		}
	}

	return m, nil
}

func (m *Manager) initEmpty() error {
	hostname, _ := os.Hostname()
	st := SBOSState{
		Version:   "1.0.0",
		Hostname:  hostname,
		UpdatedAt: time.Now(),
		Fichas:    make(map[string]*Ficha),
		Meta:      make(map[string]string),
	}
	return m.writeState(&st)
}

// validate intenta decodificar el state file para verificar integridad JSON.
// NO actualiza el estado — solo para verificación al abrir el archivo.
func (m *Manager) validate() error {
	if _, err := m.file.Seek(0, 0); err != nil {
		return err
	}
	var st SBOSState
	if err := json.NewDecoder(m.file).Decode(&st); err != nil {
		return fmt.Errorf("state: corrupt: %w", err)
	}
	return nil
}

// Read retorna el estado actual para consumidores de solo lectura.
//
// El *SBOSState retornado es inmutable — el caller no debe modificarlo.
func (m *Manager) Read() (*SBOSState, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, err := m.file.Seek(0, 0); err != nil {
		return nil, err
	}

	var st SBOSState
	if err := json.NewDecoder(m.file).Decode(&st); err != nil {
		return nil, fmt.Errorf("state: decode: %w", err)
	}
	return &st, nil
}

// readLocked decodifica el archivo sin adquirir mu — solo desde métodos que
// ya mantienen el lock (p.ej. Transition, Register).
func (m *Manager) readLocked() (*SBOSState, error) {
	if _, err := m.file.Seek(0, 0); err != nil {
		return nil, err
	}
	var st SBOSState
	if err := json.NewDecoder(m.file).Decode(&st); err != nil {
		return nil, fmt.Errorf("state: decode: %w", err)
	}
	return &st, nil
}

// writeState serializa el estado de forma atómica:
// escribe en .tmp → sync → rename → copia .bak → reabre fd.
func (m *Manager) writeState(st *SBOSState) error {
	tmpPath := m.path + ".tmp"
	bakPath := m.path + ".bak"

	tmpFile, err := os.OpenFile(tmpPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return fmt.Errorf("state: open tmp: %w", err)
	}
	enc := json.NewEncoder(tmpFile)
	enc.SetIndent("", "  ")
	if err := enc.Encode(st); err != nil {
		tmpFile.Close()
		return fmt.Errorf("state: encode: %w", err)
	}
	if err := tmpFile.Sync(); err != nil {
		tmpFile.Close()
		return fmt.Errorf("state: sync tmp: %w", err)
	}
	tmpFile.Close()

	if err := os.Rename(tmpPath, m.path); err != nil {
		return fmt.Errorf("state: rename: %w", err)
	}

	// Copia al backup — best-effort, no fatal.
	if src, err := os.Open(m.path); err == nil {
		defer src.Close()
		if dst, err := os.OpenFile(bakPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600); err == nil {
			defer dst.Close()
			io.Copy(dst, src)
		}
	}

	// Reabre el fd apuntando al nuevo inode creado por rename.
	m.file.Close()
	f, err := os.OpenFile(m.path, os.O_RDWR, 0600)
	if err != nil {
		return fmt.Errorf("state: reopen after rename: %w", err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return fmt.Errorf("state: flock after rename: %w", err)
	}
	m.file = f
	return nil
}

// Close libera el flock y cierra el archivo de estado.
func (m *Manager) Close() error {
	syscall.Flock(int(m.file.Fd()), syscall.LOCK_UN)
	return m.file.Close()
}
