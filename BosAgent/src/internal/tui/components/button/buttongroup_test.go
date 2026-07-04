package button

import (
	"strings"
	"testing"

	zone "github.com/lrstanley/bubblezone"
	"github.com/charmbracelet/lipgloss"
)

func TestMain(m *testing.M) {
	zone.NewGlobal()
	m.Run()
}

func TestButtonGroup_SingleRow(t *testing.T) {
	btns := []*Model{New("OK", Primary), New("Cancel", Secondary)}
	group := ButtonGroup{Buttons: btns, Gap: 1, AvailableWidth: 200}
	lines := strings.Split(group.View(), "\n")
	if len(lines) != 3 {
		t.Errorf("expected 3 lines, got %d", len(lines))
	}
}

func TestButtonGroup_MultiRow(t *testing.T) {
	btns := []*Model{New("Primary", Primary), New("Secondary", Secondary), New("Danger", Danger)}
	group := ButtonGroup{Buttons: btns, Gap: 1, AvailableWidth: 30}
	lines := strings.Split(group.View(), "\n")
	if len(lines) < 6 {
		t.Errorf("expected >=6 lines (2 rows), got %d", len(lines))
	}
}

func TestButtonGroup_WiderThanAvailable(t *testing.T) {
	btn := New("A very long button label", Primary)
	group := ButtonGroup{Buttons: []*Model{btn}, Gap: 1, AvailableWidth: 10}
	if !strings.Contains(group.View(), "A very long button label") {
		t.Error("content truncated")
	}
}

func TestButtonGroup_Empty(t *testing.T) {
	if g := (ButtonGroup{}); g.View() != "" {
		t.Error("expected empty for nil")
	}
}

func TestButtonGroup_NoCallsToSetters(t *testing.T) {
	btn := New("Test", Primary)
	w := lipgloss.Width(btn.View())
	ButtonGroup{Buttons: []*Model{btn}, Gap: 1, AvailableWidth: 200}.View()
	if lipgloss.Width(btn.View()) != w {
		t.Error("View() modified button width")
	}
}

func TestHoverStyleUsesFocused(t *testing.T) {
	btn := New("HoverTest", Primary)
	btn.hovered = true
	s := btn.styleFor()
	if s.GetBorderTopForeground() != btn.focused_.GetBorderTopForeground() {
		t.Error("hover must use focused style")
	}
}

func TestFocusedWinsOverHovered(t *testing.T) {
	btn := New("FocusWins", Primary)
	btn.hovered = true
	btn.focused = true
	s := btn.styleFor()
	if s.GetBorderTopForeground() != btn.focused_.GetBorderTopForeground() {
		t.Error("focused must win over hover")
	}
}
