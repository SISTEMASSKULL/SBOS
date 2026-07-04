// Package toml provides a minimal TOML decoder for bos configuration.
// Supports the subset used by bos.toml and bos-install.toml:
// key = value (string, int, bool), [section] headers, inline tables.
package toml

import (
	"fmt"
	"os"
	"reflect"
	"strconv"
	"strings"
)

// DecodeFile lee un archivo TOML y decodifica su contenido en el struct apuntado por v.
//
// Recibe:
//   - path: string — ruta absoluta al archivo TOML.
//   - v: interface{} — puntero a struct destino con etiquetas `toml:`.
//
// Retorna: (nil, error) — el primer retorno es siempre nil (compatibilidad futura).
//
// Callers conocidos:
//   - internal/config/config.go:Load — para bos.toml y bos-install.toml.
//
// Efectos secundarios: lee el archivo de disco.
func DecodeFile(path string, v interface{}) (interface{}, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return nil, Unmarshal(data, v)
}

// Unmarshal decodifica datos TOML en el struct apuntado por v.
//
// Recibe:
//   - data: []byte — contenido TOML en memoria.
//   - v: interface{} — puntero a struct destino con etiquetas `toml:`.
//
// Retorna: error si v no es puntero a struct, o si hay valores inválidos.
//
// Efectos secundarios: ninguno — solo modifica el struct destino.
func Unmarshal(data []byte, v interface{}) error {
	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Ptr || rv.Elem().Kind() != reflect.Struct {
		return fmt.Errorf("toml: expected pointer to struct, got %T", v)
	}
	st := rv.Elem()
	stType := st.Type()

	lines := strings.Split(string(data), "\n")
	section := "" // current [section]
	fieldIndex := buildTagIndex(stType)

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		// Section header [name]
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			section = trimmed[1 : len(trimmed)-1]
			continue
		}

		// key = value
		eq := strings.IndexByte(trimmed, '=')
		if eq < 0 {
			continue
		}
		key := strings.TrimSpace(trimmed[:eq])
		rawVal := strings.TrimSpace(trimmed[eq+1:])

		// Resolve which struct field this maps to
		var field reflect.Value
		if section != "" {
			field = findSectionField(st, stType, section, key, fieldIndex)
		} else {
			field = findTopField(st, key, fieldIndex)
		}

		if !field.IsValid() {
			continue
		}

		val, err := parseValue(rawVal, field.Type())
		if err != nil {
			return fmt.Errorf("toml: %s: %w", key, err)
		}
		field.Set(val)
	}

	return nil
}

type tagIndex struct {
	tomlName  string
	fieldIdx  int
	subFields map[string]int // toml tag → field index for sub-structs
}

func buildTagIndex(stType reflect.Type) map[string]*tagIndex {
	idx := make(map[string]*tagIndex)
	for i := 0; i < stType.NumField(); i++ {
		f := stType.Field(i)
		tag := f.Tag.Get("toml")
		if tag == "" || tag == "-" {
			continue
		}
		ti := &tagIndex{tomlName: tag, fieldIdx: i}
		if f.Type.Kind() == reflect.Struct {
			ti.subFields = make(map[string]int)
			for j := 0; j < f.Type.NumField(); j++ {
				sf := f.Type.Field(j)
				st := sf.Tag.Get("toml")
				if st != "" {
					ti.subFields[st] = j
				}
			}
			// Also register subsection by section name
			idx[tag] = ti
		}
		idx[tag] = ti
	}
	return idx
}

func findTopField(st reflect.Value, key string, idx map[string]*tagIndex) reflect.Value {
	if ti, ok := idx[key]; ok {
		f := st.Field(ti.fieldIdx)
		if f.Kind() == reflect.Struct {
			return f
		}
		return f
	}
	return reflect.Value{}
}

func findSectionField(st reflect.Value, stType reflect.Type, section, key string, idx map[string]*tagIndex) reflect.Value {
	ti, ok := idx[section]
	if !ok {
		return reflect.Value{}
	}
	parent := st.Field(ti.fieldIdx)
	if parent.Kind() != reflect.Struct {
		return reflect.Value{}
	}
	if subIdx, ok := ti.subFields[key]; ok {
		return parent.Field(subIdx)
	}
	return reflect.Value{}
}

func parseValue(raw string, targetType reflect.Type) (reflect.Value, error) {
	raw = strings.Trim(raw, `"'`)

	switch targetType.Kind() {
	case reflect.String:
		return reflect.ValueOf(raw), nil
	case reflect.Int:
		v, err := strconv.Atoi(raw)
		if err != nil {
			return reflect.Value{}, err
		}
		return reflect.ValueOf(v), nil
	case reflect.Bool:
		switch strings.ToLower(raw) {
		case "true", "1", "yes":
			return reflect.ValueOf(true), nil
		case "false", "0", "no":
			return reflect.ValueOf(false), nil
		}
		return reflect.Value{}, fmt.Errorf("invalid bool: %s", raw)
	case reflect.Float64:
		v, err := strconv.ParseFloat(raw, 64)
		if err != nil {
			return reflect.Value{}, err
		}
		return reflect.ValueOf(v), nil
	default:
		return reflect.ValueOf(nil), fmt.Errorf("unsupported type: %s", targetType.Kind())
	}
}
