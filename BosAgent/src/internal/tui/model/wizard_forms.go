// Package model — wizard_forms.go: constructores de formularios huh para el wizard de instalación.
// T-080→T-083 (Bloque 8): migración de textinput manual a huh v1.0.0.
//
// Patrón de uso (igual que AuthForm):
//  1. Form se inicializa nil en Model.
//  2. HandleUpdate lo crea la primera vez que la pantalla se activa.
//  3. Los mensajes se delegan al form mientras State == huh.StateNormal.
//  4. Cuando State == huh.StateCompleted, los valores ya están en los campos string del Model.
//  5. Form se resetea a nil al salir de la pantalla (para re-inicializar con valores actuales en próxima visita).
package model

import (
	"errors"
	"fmt"
	"strings"

	"bos/internal/tui/styles"
	"github.com/charmbracelet/huh"
)


// NewWizardP1Form construye el form de bienvenida del wizard (S01).
// Menú de selección: 0=Comenzar instalación, 1=Salir.
// Resultado en m.WizardP1Selection.
func NewWizardP1Form(m *Model) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[int]().
				Title("¿Qué desea hacer?").
				Options(
					huh.NewOption("Comenzar instalación", 0),
					huh.NewOption("Salir", 1),
				).
				Value(&m.WizardP1Selection),
		),
	).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// NewWizardP2Form construye el form de datos del tenant (S02).
// Vincula los 4 campos a m.TenantName, m.TenantNIT, m.TenantPais, m.TenantDomain.
func NewWizardP2Form(m *Model) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Razón social").
				Placeholder("(requerido)").
				Value(&m.TenantName).
				Validate(func(s string) error {
					if strings.TrimSpace(s) == "" {
						return errors.New("la razón social es obligatoria")
					}
					return nil
				}),
			huh.NewInput().
				Title("NIT / CUIT / RFC").
				Placeholder("(requerido)").
				Value(&m.TenantNIT).
				Validate(func(s string) error {
					if strings.TrimSpace(s) == "" {
						return errors.New("el NIT es obligatorio")
					}
					return nil
				}),
			huh.NewInput().
				Title("País [BO/AR/MX]").
				Placeholder("BO · AR · MX  (requerido)").
				Value(&m.TenantPais).
				Validate(func(s string) error {
					p := strings.ToUpper(strings.TrimSpace(s))
					if p != "BO" && p != "AR" && p != "MX" {
						return errors.New("país inválido — use BO, AR o MX")
					}
					return nil
				}),
			huh.NewInput().
				Title("Dominio").
				Placeholder("(se genera automáticamente si lo deja vacío)").
				Value(&m.TenantDomain),
		),
	).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// NewWizardP3Form construye el form de cuenta de administrador (S03).
// Vincula campos a m.AdminEmail, m.AdminNombre, m.AdminPassword, m.AdminPasswordConfirm y m.MFAEnabled.
func NewWizardP3Form(m *Model) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Email del administrador").
				Placeholder("usuario@dominio.com  (requerido)").
				Value(&m.AdminEmail).
				Validate(validateEmail),
			huh.NewInput().
				Title("Nombre completo").
				Placeholder("(requerido)").
				Value(&m.AdminNombre).
				Validate(validateNotEmpty("el nombre")),
			huh.NewInput().
				Title("Contraseña").
				Placeholder("mínimo 8 caracteres").
				EchoMode(huh.EchoModePassword).
				Value(&m.AdminPassword).
				Validate(func(s string) error {
					if len(s) < 8 {
						return errors.New("mínimo 8 caracteres")
					}
					return nil
				}),
			huh.NewInput().
				Title("Confirmar contraseña").
				Placeholder("repetir contraseña").
				EchoMode(huh.EchoModePassword).
				Value(&m.AdminPasswordConfirm).
				Validate(func(s string) error {
					if s != m.AdminPassword {
						return errors.New("las contraseñas no coinciden")
					}
					return nil
				}),
			huh.NewConfirm().
				Title("MFA — Push Multi-Factor Authentication").
				Description("Activa autenticación push de dos factores vía sbos-notifier.").
				Affirmative("Activar MFA").
				Negative("Sin MFA").
				Value(&m.MFAEnabled),
		),
	).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// NewWizardP4Form construye el form de confirmación antes de instalar (S04).
// Solo contiene el huh.NewConfirm() — el resumen se renderiza desde los campos del Model
// en renderConfirmBody() para que refleje el estado actual sin depender de la captura de punteros.
// Resultado en m.WizardP4Confirm.
func NewWizardP4Form(m *Model) *huh.Form {
	return huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("¿Iniciar instalación ahora?").
				Description("Se iniciará el bootstrap SBOS (~48 min). Esta acción es irreversible.").
				Affirmative("Iniciar instalación").
				Negative("Volver a corregir").
				Value(&m.WizardP4Confirm),
		),
	).WithKeyMap(styles.HuhKeyMap()).WithTheme(styles.HuhTheme())
}

// WizardP4Summary genera el resumen de instalación desde los campos actuales del Model.
// Se usa en renderConfirmBody (s04_confirmar.go) para display dinámico.
func WizardP4Summary(m *Model) string {
	pais := m.TenantPais
	if pais == "" {
		pais = "BO"
	}
	mfaStr := "Desactivado"
	if m.MFAEnabled {
		mfaStr = "Push MFA ✓"
	}
	dominio := m.TenantDomain
	if dominio == "" {
		dominio = BuildSlug(m.TenantName) + ".sksistemas.com"
	}
	return fmt.Sprintf(
		"Empresa:  %s\nNIT:      %s\nPaís:     %s\nDominio:  %s\n\nAdmin:    %s\nNombre:   %s\nMFA:      %s",
		m.TenantName, m.TenantNIT, pais, dominio,
		m.AdminEmail, m.AdminNombre, mfaStr,
	)
}
