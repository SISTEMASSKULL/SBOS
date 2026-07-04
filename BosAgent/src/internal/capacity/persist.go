package capacity

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

const DefaultPath = "/etc/bos/capacity.yaml"

// Save persiste el Estimate en path (YAML). Crea el directorio si no existe.
func Save(e Estimate, path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0750); err != nil {
		return fmt.Errorf("capacity.Save: mkdir %s: %w", filepath.Dir(path), err)
	}
	type wire struct {
		Tenants            int `yaml:"tenants"`
		CompaniesPerTenant int `yaml:"companies_per_tenant"`
		BranchesPerCompany int `yaml:"branches_per_company"`
		UsersPerBranch     int `yaml:"users_per_branch"`
	}
	data, err := yaml.Marshal(wire{
		Tenants:            e.Tenants,
		CompaniesPerTenant: e.CompaniesPerTenant,
		BranchesPerCompany: e.BranchesPerCompany,
		UsersPerBranch:     e.UsersPerBranch,
	})
	if err != nil {
		return fmt.Errorf("capacity.Save: marshal: %w", err)
	}
	return os.WriteFile(path, data, 0640)
}

// Load lee un Estimate desde path. Retorna Estimate{} y error si el archivo no existe.
func Load(path string) (Estimate, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return Estimate{}, fmt.Errorf("capacity.Load: %w", err)
	}
	type wire struct {
		Tenants            int `yaml:"tenants"`
		CompaniesPerTenant int `yaml:"companies_per_tenant"`
		BranchesPerCompany int `yaml:"branches_per_company"`
		UsersPerBranch     int `yaml:"users_per_branch"`
	}
	var w wire
	if err := yaml.Unmarshal(raw, &w); err != nil {
		return Estimate{}, fmt.Errorf("capacity.Load: unmarshal: %w", err)
	}
	return Estimate{
		Tenants:            w.Tenants,
		CompaniesPerTenant: w.CompaniesPerTenant,
		BranchesPerCompany: w.BranchesPerCompany,
		UsersPerBranch:     w.UsersPerBranch,
	}, nil
}

// ParseEnv lee las cuatro variables de entorno BOS_CAP_* y construye un Estimate.
// Retorna Estimate{} si alguna variable falta o no es un entero positivo.
func ParseEnv() (Estimate, error) {
	keys := []string{"BOS_CAP_TENANTS", "BOS_CAP_COMPANIES", "BOS_CAP_BRANCHES", "BOS_CAP_USERS"}
	vals := make([]int, 4)
	for i, k := range keys {
		v := strings.TrimSpace(os.Getenv(k))
		if v == "" {
			return Estimate{}, fmt.Errorf("capacity.ParseEnv: %s no definida", k)
		}
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return Estimate{}, fmt.Errorf("capacity.ParseEnv: %s=%q no es un entero positivo", k, v)
		}
		vals[i] = n
	}
	return Estimate{
		Tenants:            vals[0],
		CompaniesPerTenant: vals[1],
		BranchesPerCompany: vals[2],
		UsersPerBranch:     vals[3],
	}, nil
}
