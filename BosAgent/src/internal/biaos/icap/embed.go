package icap

// embed.go — helper de decodificación JSON (sin importar encoding/json en
// engine.go dos veces) — F10.3.

import (
	"encoding/json"
	"io"
)

func jsonDecode(r io.Reader, v interface{}) error {
	return json.NewDecoder(r).Decode(v)
}
