/**
 * bi18n-tipos.ts — Tipos públicos del SDK bi18n UI v2.0.0
 * Propósito: contratos TypeScript compartidos entre cliente, SDK y adaptadores.
 */

/** JSON config que describe un campo de formulario. Siempre JSON — nunca string DSL. */
export interface TipoConfig {
  // ── Requerido ──────────────────────────────────────────────────────────────
  base: "CI" | "NIT" | "email" | "phone" | "date" | "money"
      | "number" | "text" | "password" | "bool" | "enum";

  // ── Subtipos ────────────────────────────────────────────────────────────────
  pais?:       string;                              // CI, NIT, phone
  moneda?:     string;                              // money: "BOB" | "USD" | "EUR"
  subtipo?:    "integer" | "decimal" | "percent" | "alpha" | "alphanumeric"; // number, text
  decimales?:  number;                              // number, money
  catalogo?:   string;                              // enum

  // ── Rango ───────────────────────────────────────────────────────────────────
  min?:        number;                              // money, number
  max?:        number;
  min_fecha?:  string;                              // date — ISO o "hoy-18a"
  max_fecha?:  string;
  min_chars?:  number;                              // text
  max_chars?:  number;

  // ── Validación cruzada ──────────────────────────────────────────────────────
  confirmar?:  string;                              // selector CSS del campo referencia
  distinto?:   string;
  mayor_que?:  string;
  menor_que?:  string;

  // ── Advertencias (onWarn) ────────────────────────────────────────────────────
  warn_min?:   number;   // money/number: warn si valor < warn_min
  warn_max?:   number;   // money/number: warn si valor > warn_max
  warn_dias?:  number;   // date: warn si la fecha vence en ≤ N días desde hoy

  // ── Email avanzado ──────────────────────────────────────────────────────────
  verificar_mx?:       boolean;
  verificar_smtp?:     boolean;
  detectar_typo?:      boolean;
  rechazar_temporal?:  boolean;

  // ── Control ─────────────────────────────────────────────────────────────────
  requerido?:   boolean;
  mask?:        string;                             // override de máscara de entrada
  format?:      string;                             // override de formato display

  // ── UX ──────────────────────────────────────────────────────────────────────
  placeholder?: string;
  label?:       string;

  // ── Mensajes personalizados ─────────────────────────────────────────────────
  msgOk?:       string;
  msgWarn?:     string;
  msgError?:    string;
}

/** Resultado devuelto por el daemon al validar un campo. */
export interface ResultadoValidacion {
  valido:             boolean;
  valor_normalizado:  string;
  mensaje:            string;    // msgOk | msgWarn | msgError según estado
  errores:            string[];
  metadata:           Record<string, unknown>;
}

/** Patrón de máscara devuelto por bi18n.mask.pattern */
export interface PatronMascara {
  motor:        string;          // "Pattern" | "Date" | "Number" | "none"
  patron:       string | null;
  opciones:     Record<string, unknown>;
  placeholder:  string | null;
  usar_mascara: boolean;
}

/** Vínculo activo: retornado por bSet(). Chainable para eventos, destruible con bUnSet(). */
export interface Vinculo {
  bUnSet():  void;
  onValid  (cb: (r: ResultadoValidacion) => void): Vinculo;
  onInvalid(cb: (r: ResultadoValidacion) => void): Vinculo;
  onWarn   (cb: (r: ResultadoValidacion) => void): Vinculo;
  onError  (cb: (e: Error)              => void): Vinculo;
  readonly valor: string;
}

/** Config de columna para mostrar_lote */
export interface ConfigColumna {
  campo:    string;
  tipo?:    TipoConfig;
  mascara?: string;
  formato?: string;
}

/** Entrada en el schema de formulario */
export interface CampoSchema {
  id:     string;          // selector sin # (el SDK añade #)
  config: TipoConfig;
}
