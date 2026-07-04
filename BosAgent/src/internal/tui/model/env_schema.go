// Package model — env_schema.go: esquema declarativo de los campos del .env del instalador.
// Para agregar un campo nuevo al formulario: agregar una entrada aquí y declarar
// la variable correspondiente en bos-bootstrap.env. El wizard la muestra automáticamente.
package model

// EnvField describe un campo del formulario de instalación derivado del .env.
type EnvField struct {
	EnvKey      string // variable en bos-bootstrap.env, ej. BOS_TENANT_NAME
	Label       string // etiqueta visible en el formulario
	Placeholder string // texto de ayuda cuando el campo está vacío
	HelpText    string // descripción larga en el panel de ayuda contextual (S02)
	HelpExample string // ejemplo de valor válido (S02)
	Section     string // "tenant" | "admin" | "capacity"
	Secret      bool   // true → campo de contraseña (oculta caracteres)
	Required    bool
	Numeric     bool   // true → solo acepta enteros positivos; se valida en blur
}

// TenantSchema define los campos del paso "Datos de la empresa" (S02).
// El orden aquí es el orden de tabulación en el formulario.
// Para agregar un campo nuevo: insertar aquí y declarar BOS_* en bos-bootstrap.env.
var TenantSchema = []EnvField{
	{
		EnvKey:      "BOS_TENANT_NAME",
		Label:       "Razón social",
		Placeholder: "(requerido)",
		HelpText:    "Nombre legal completo de su empresa tal como aparece en documentos fiscales oficiales.",
		HelpExample: "Sistemas SKULL S.A. · ACME Consultores Ltda.",
		Section:     "tenant",
		Required:    true,
	},
	{
		EnvKey:      "BOS_TENANT_NIT",
		Label:       "NIT / CUIT / RFC",
		Placeholder: "(requerido)",
		HelpText:    "Identificador fiscal único. En Bolivia: NIT. En Argentina: CUIT. En México: RFC.",
		HelpExample: "1025463029 · 20-12345678-9 · AAA010101AAA",
		Section:     "tenant",
		Required:    true,
	},
	{
		EnvKey:      "BOS_TENANT_PAIS",
		Label:       "País [BO/AR/MX]",
		Placeholder: "BO  AR  MX  (requerido)",
		HelpText:    "País donde opera la empresa. Determina el módulo fiscal y las reglas de cumplimiento.",
		HelpExample: "BO · AR · MX · CL · PE · CO",
		Section:     "tenant",
		Required:    true,
	},
	{
		EnvKey:      "BOS_TENANT_DOMAIN",
		Label:       "Dominio",
		Placeholder: "(se genera automáticamente si lo deja vacío)",
		HelpText:    "Dominio base para los servicios SBOS. Se usará en certificados TLS y subdominios.",
		HelpExample: "sksistemas.com · miempresa.bo · consultech.com.ar",
		Section:     "tenant",
	},
}

// CapacitySchema define los campos del paso "Estimados de capacidad" (P3B).
// Los valores son estimados — el sistema calcula los requisitos de hardware a partir de ellos.
// No son límites estrictos en instalación sino la base para el observer y el control de admisión.
var CapacitySchema = []EnvField{
	{
		EnvKey:      "BOS_CAP_TENANTS",
		Label:       "Número de tenants",
		Placeholder: "ej. 5",
		HelpText:    "Cantidad de tenants (clientes) que operarán en este servidor. Cada tenant tiene sus propias empresas, sucursales y usuarios en namespaces aislados.",
		HelpExample: "Empresa pequeña: 1–5 · Integradora: 10–50 · ISP/SaaS: 100+",
		Section:     "capacity",
		Required:    true,
		Numeric:     true,
	},
	{
		EnvKey:      "BOS_CAP_COMPANIES",
		Label:       "Empresas por tenant",
		Placeholder: "ej. 10",
		HelpText:    "Promedio de empresas que cada tenant administrará. Determina el número de schemas en PostgreSQL y los replication slots de bKernel.",
		HelpExample: "Mono-empresa: 1 · Holding: 5–20 · Franquicia: 50–200",
		Section:     "capacity",
		Required:    true,
		Numeric:     true,
	},
	{
		EnvKey:      "BOS_CAP_BRANCHES",
		Label:       "Sucursales por empresa",
		Placeholder: "ej. 5",
		HelpText:    "Promedio de sucursales por empresa. Determina los hash slots de Redis, las upstream pools de Kong y los POS lógicos del Context Plane.",
		HelpExample: "Local único: 1 · Cadena: 5–30 · Nacional: 50–500",
		Section:     "capacity",
		Required:    true,
		Numeric:     true,
	},
	{
		EnvKey:      "BOS_CAP_USERS",
		Label:       "Usuarios por sucursal",
		Placeholder: "ej. 20",
		HelpText:    "Promedio de usuarios por sucursal. Junto con los demás estimados calcula los ctx_id concurrentes, el tamaño de Redis DB1 y los recursos de Keycloak.",
		HelpExample: "Caja única: 2–5 · Oficina: 10–30 · Centro grande: 50–200",
		Section:     "capacity",
		Required:    true,
		Numeric:     true,
	},
}

// AdminSchema define los campos del paso "Cuenta de administrador" (S03).
// El orden aquí es el orden de tabulación en el formulario.
var AdminSchema = []EnvField{
	{
		EnvKey:      "BOS_ROOT_USER",
		Label:       "Email",
		Placeholder: "usuario@dominio.com  (requerido)",
		Section:     "admin",
		Required:    true,
	},
	{
		EnvKey:      "BOS_ADMIN_NOMBRE",
		Label:       "Nombre completo",
		Placeholder: "(requerido)",
		Section:     "admin",
		Required:    true,
	},
	{
		EnvKey:      "BOS_ROOT_PASSWORD",
		Label:       "Contraseña",
		Placeholder: "mínimo 8 caracteres",
		Section:     "admin",
		Secret:      true,
		Required:    true,
	},
	{
		EnvKey:      "BOS_ROOT_PASSWORD_CONFIRM",
		Label:       "Confirmar contraseña",
		Placeholder: "repetir contraseña",
		Section:     "admin",
		Secret:      true,
		Required:    true,
	},
}
