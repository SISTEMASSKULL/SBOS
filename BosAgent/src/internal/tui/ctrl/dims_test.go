package ctrl

import (
	"fmt"
	"strings"
	"testing"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

func TestDims(t *testing.T) {
	w, h := 100, 30
	fmt.Printf("\n=== Test dimensiones %dx%d ===\n", w, h)

	for i, item := range dash.MenuDef {
		if item.ViewKey == "" {
			continue
		}
		dm := New(w, h)
		dm.MenuIdx = i
		rendered := Render(dm)
		lines := strings.Split(rendered, "\n")
		vLines := styles.TextHeight(rendered)
		ok := "✅"
		if len(lines) != h || vLines != h {
			ok = "🔴"
		}
		fmt.Printf("%s idx=%-2d %-20s lines=%-3d visual=%-3d (esperado=%d)\n",
			ok, i, item.Label, len(lines), vLines, h)
	}
}

func TestDiagViews(t *testing.T) {
	w, h := 100, 30
	dm := New(w, h)

	topBar := renderTopBar(dm)
	bottomBar := renderBottomBar(dm)
	topH := styles.TextHeight(topBar)
	botH := styles.TextHeight(bottomBar)
	midH := h - topH - botH

	menuW := w * 2 / 12
	if menuW < 22 {
		menuW = 22
	}
	contW := w - menuW
	innerW := contW - 4
	innerH := midH - 2
	bodyH := innerH - 4

	fmt.Printf("\n=== Diagnóstico de vistas (w=%d h=%d midH=%d bodyH=%d innerW=%d) ===\n",
		w, h, midH, bodyH, innerW)

	cases := []struct {
		idx  int
		name string
	}{
		{0, "Overview"},
		{4, "Workloads"},
		{16, "Jobs"},
	}

	for _, c := range cases {
		dm2 := New(w, h)
		dm2.MenuIdx = c.idx

		body := renderContainerBody(dm2, innerW, bodyH)
		bodyLines := strings.Split(body, "\n")
		fmt.Printf("%-12s renderBody=%d lines (bodyH=%d)\n", c.name, len(bodyLines), bodyH)

		for i, line := range bodyLines {
			lw := styles.TextWidth(line)
			if lw > innerW {
				fmt.Printf("  OVERFLOW línea %d: visual_width=%d > innerW=%d\n", i, lw, innerW)
				if i < 3 {
					trunc := line
					if len(trunc) > 60 {
						trunc = trunc[:60]
					}
					fmt.Printf("  content: %q\n", trunc)
				}
			}
		}
	}
}
