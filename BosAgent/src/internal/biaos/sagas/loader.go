package sagas

// loader.go — F10.4: carga de sagas declarativas desde sagas/*.yml
// (BOS-REPAIR-10 §3.2 — mismo formato del manual JSON-RPC Parte 9).
// Parser plano propio, igual estilo que el catálogo ICAP.

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// CargarDefiniciones lee todas las sagas *.yml del directorio.
// Producción: /etc/bos/ai/sagas/. Retorna map nombre→Definicion.
func CargarDefiniciones(dir string) (map[string]Definicion, error) {
	entradas, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("sagas: leer %s: %w", dir, err)
	}
	defs := make(map[string]Definicion)
	for _, e := range entradas {
		if e.IsDir() || (!strings.HasSuffix(e.Name(), ".yml") && !strings.HasSuffix(e.Name(), ".yaml")) {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		def, err := parsearDefinicion(string(data))
		if err != nil || def.Nombre == "" {
			continue
		}
		defs[def.Nombre] = def
	}
	return defs, nil
}

// parsearDefinicion extrae nombre y pasos del YAML plano.
//
// Formato:
//
//	nombre: node-maintain
//	pasos:
//	  - id: cordon
//	    metodo: bos.k8s.node.cordon
//	    compensacion: bos.k8s.node.uncordon
//	    depende_de: [otro_paso]
func parsearDefinicion(content string) (Definicion, error) {
	var def Definicion
	var actual *Paso

	flush := func() {
		if actual != nil && actual.ID != "" {
			def.Pasos = append(def.Pasos, *actual)
		}
		actual = nil
	}

	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.HasPrefix(trimmed, "- id:") {
			flush()
			actual = &Paso{ID: strings.TrimSpace(strings.TrimPrefix(trimmed, "- id:"))}
			continue
		}
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), `"'`)

		if actual == nil {
			if key == "nombre" {
				def.Nombre = value
			}
			continue
		}
		switch key {
		case "metodo":
			actual.Metodo = value
		case "compensacion":
			if value != "null" {
				actual.Compensacion = value
			}
		case "depende_de":
			v := strings.Trim(value, "[]")
			for _, d := range strings.Split(v, ",") {
				if s := strings.TrimSpace(d); s != "" {
					actual.DependeDe = append(actual.DependeDe, s)
				}
			}
		}
	}
	flush()
	if def.Nombre == "" {
		return def, fmt.Errorf("sagas: definición sin nombre")
	}
	return def, nil
}
