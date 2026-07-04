# Estructura Completa del TUI — BosAgent SBOS

```
internal/tui/

├── ESTRUCTURA-TUI.md (6,095b) 📄
├── PARIDAD.md (10,348b) 📄
├── POLICY.md (8,358b) 📄
├── SBOS-THEME-ABYSS.md (99,323b) 📄
├── THEME-COMPLETO.md (131,710b) 📄
├── TUI-MAESTRO.md (228,419b) 📄
├── doc.go (2,327b) 📝
├── icon.go (3,903b) 
├── logosbos.png (4,349b) 
├── manual_componentes_tui_go.md (141,777b) 📄
│
├── 📁 app/ (2 files)
├── app.go (3,668b)
├── huh_integration_test.go (3,412b) 🧪
├── 📁 assets/ (1 files)
├── sbos-icon.png (4,349b)
├── 📁 components/ (1 files)
├── doc.go (736b) 📝
├── 📁 button/ (3 files)
│   ├── button.go (24,383b)
│   ├── button_test.go (13,821b) 🧪
│   ├── buttongroup_test.go (2,019b) 🧪
├── 📁 floating/ (0 files)
├── 📁 focus/ (1 files)
│   ├── manager.go (1,985b)
├── 📁 panel/ (1 files)
│   ├── panel.go (5,082b)
├── 📁 spacer/ (1 files)
│   ├── spacer.go (598b)
├── 📁 ctrl/ (4 files)
├── dims_test.go (1,801b) 🧪
├── doc.go (2,018b) 📝
├── model.go (918b)
├── render.go (10,476b)
├── 📁 dash/ (7 files)
│   ├── doc.go (522b) 📝
│   ├── keys.go (3,323b)
│   ├── menu.go (3,838b)
│   ├── model.go (18,905b)
│   ├── tick.go (2,879b)
│   ├── types.go (9,750b)
│   ├── widgets.go (8,240b)
├── 📁 data/ (0 files)
├── 📁 k8s/ (6 files)
│   ├── as.go (9,257b)
│   ├── cp.go (1,975b)
│   ├── doc.go (141b) 📝
│   ├── net.go (4,508b)
│   ├── sto.go (6,173b)
│   ├── wl.go (2,403b)
├── 📁 panel/ (13 files)
│   ├── alertas.go (1,858b)
│   ├── backups.go (4,715b)
│   ├── config.go (4,132b)
│   ├── doc.go (205b) 📝
│   ├── jobs.go (2,845b)
│   ├── logs.go (6,710b)
│   ├── monitoreo.go (4,291b)
│   ├── net_os.go (4,770b)
│   ├── overview.go (5,955b)
│   ├── pam.go (4,783b)
│   ├── seguridad.go (6,278b)
│   ├── stor_os.go (4,128b)
│   ├── usuarios.go (3,452b)
├── 📁 sistema/ (7 files)
│   ├── disco.go (2,688b)
│   ├── doc.go (149b) 📝
│   ├── kernel.go (2,824b)
│   ├── metricas.go (4,029b)
│   ├── procesos.go (3,030b)
│   ├── red.go (3,791b)
│   ├── systemd.go (1,861b)
├── 📁 views/ (0 files)
├── 📁 widgets/ (0 files)
├── 📁 demo/ (2 files)
├── demo.go (6,512b)
├── doc.go (1,960b) 📝
├── 📁 model/ (18 files)
├── auth.go (7,052b)
├── doc.go (2,985b) 📝
├── env_loader.go (2,544b)
├── env_schema.go (5,310b)
├── events.go (1,985b)
├── keys.go (11,938b)
├── model.go (16,889b)
├── model_test.go (8,427b) 🧪
├── phases.go (1,998b)
├── preflight.go (5,900b)
├── sysinfo.go (2,461b)
├── types.go (3,472b)
├── update.go (35,903b)
├── update_wizard.go (6,082b)
├── update_wizard_test.go (8,375b) 🧪
├── viewport.go (2,565b)
├── wizard_forms.go (5,420b)
├── ws.go (6,871b)
├── 📁 observer/ (2 files)
├── reader.go (9,356b)
├── reader_test.go (2,088b) 🧪
├── 📁 screens/ (32 files)
├── _template.go.tmpl (745b)
├── dispatcher.go (1,415b)
├── dispatcher_test.go (2,117b) 🧪
├── doc.go (3,270b) 📝
├── helpers.go (1,858b)
├── installing_test.go (12,244b) 🧪
├── s00_welcome.go (4,686b)
├── s00_welcome_test.go (2,608b) 🧪
├── s01_bienvenida.go (1,649b)
├── s02_empresa.go (730b)
├── s03_admin.go (775b)
├── s03b_capacidad.go (4,357b)
├── s04_confirmar.go (1,951b)
├── s05_instalando.go (21,830b)
├── s05b_log.go (2,138b)
├── s05c_error.go (3,597b)
├── s06_done.go (9,500b)
├── s06_done_test.go (4,532b) 🧪
├── s07_reboot.go (2,450b)
├── s07_reboot_test.go (2,778b) 🧪
├── s08_boot.go (3,052b)
├── s08_boot_test.go (4,352b) 🧪
├── s11_shutdown.go (2,954b)
├── s11_shutdown_test.go (3,479b) 🧪
├── s99_goodbye.go (3,228b)
├── s99_goodbye_test.go (2,380b) 🧪
├── sauth_confirm.go (1,464b)
├── sauth_confirm_test.go (3,190b) 🧪
├── sauth_login.go (952b)
├── sauth_login_test.go (3,040b) 🧪
├── shared.go (10,541b)
├── wizard_test.go (13,476b) 🧪
├── 📁 styles/ (15 files)
├── AUDITORIA-THEME.md (17,514b) 📄
├── README.MD (2,366b)
├── doc.go (2,194b) 📝
├── grid.go (3,721b)
├── huh_theme.go (5,696b)
├── icons.go (14,687b)
├── layout.go (2,438b)
├── styles.go (1,468b)
├── theme.go (33,928b)
├── theme.go.bak (17,205b)
├── tokens_component.go (31,032b)
├── tokens_primitive.go (12,951b)
├── tokens_semantic.go (16,452b)
├── tokens_semantic.go.bak (12,094b)
├── tokens_state.go (9,168b)
├── 📁 tuilog/ (2 files)
├── tuilog.go (17,992b)
├── tuilog_test.go (22,070b) 🧪
├── 📁 util/ (4 files)
├── ficha.go (970b)
├── ficha_test.go (1,269b) 🧪
├── format.go (2,260b)
├── format_test.go (3,089b) 🧪
```

**Total:** 132 archivos · 1,380,278 bytes · 24 directorios

---

## Resumen por categoría

| Directorio | Archivos | Descripción |
|-----------|---------|-------------|
| `styles/` | 15 | Tokens de color, temas, iconos, grid, layouts |
| `components/` | 6 | Componentes reutilizables (button, panel, focus, spacer, floating) |
| `screens/` | 32 | Pantallas del wizard de instalación (S00-S99, auth) |
| `model/` | 18 | Modelo principal, eventos, fases, viewport, wizard forms |
| `ctrl/` | 11 | Controladores: dashboard, k8s, sistema, panel (admin) |
| `demo/` | 2 | Demo de theme preview |
| `util/` | 4 | Utilidades: fichas, formateo |
| `tuilog/` | 2 | Sistema de logging para TUI |
| `observer/` | 2 | Lector de archivos con polling |
| `app/` | 2 | Configuración de la aplicación TUI |
| `components/button/` | 3 | Botones con Focus/Blur/Hover/Pressed/Toggle + ButtonGroup |
| `components/panel/` | 1 | Paneles con PanelManager + FloatingPanel |
| `components/focus/` | 1 | Interfaz Component + FocusManager |
| `components/spacer/` | 1 | Separadores con fondo del panel |
| `components/floating/` | 0 | Paneles flotantes (modal) |