/**
 * bi18n-sdk.ts — SDK bi18n UI v2.0.0 — punto de entrada público.
 * Propósito: API declarativa para vincular campos de formulario al daemon bi18n.
 *
 *   campo(sel).tipo({...}).bSet()     → Vinculo  (síncrono — máscara async en background)
 *   valor(raw).formato("date:long").obtener()
 *   mostrar(sel).valor(v).tipo({...}).render()
 *   formulario(sel, schema).al_enviar(cb).bSet()
 *
 * bSet() es síncrono: retorna Vinculo inmediatamente, máscara se aplica async (< 50 ms,
 * daemon local) — antes de que el usuario haya interactuado con el campo.
 *
 * Dependencias: Bi18nClient, VinculoImpl, TipoConfig
 * Especificación: A.19 v2.0.0 · 1.04 §11-§18
 */

import { Bi18nClient }  from "./bi18n-client.ts";
import { VinculoImpl }  from "./bi18n-vinculo.ts";
import type {
  TipoConfig, Vinculo, ResultadoValidacion,
  PatronMascara, ConfigColumna, CampoSchema,
} from "./bi18n-tipos.ts";

export * from "./bi18n-tipos.ts";

// ── Helper ────────────────────────────────────────────────────────────────────

function uuid(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function resolverEl(sel: string | Element): HTMLInputElement {
  const el = typeof sel === "string" ? document.querySelector(sel) : sel;
  if (!el) throw new Error(`bi18n: elemento no encontrado — "${sel}"`);
  return el as HTMLInputElement;
}

// ── CampoBuilder ──────────────────────────────────────────────────────────────

/** Construye un vínculo de campo. Termina en .bSet(). */
class CampoBuilder {
  private _config: TipoConfig | null = null;

  constructor(
    private readonly el:      HTMLInputElement,
    private readonly cliente: Bi18nClient,
  ) {}

  /** JSON config del campo — siempre JSON, nunca string DSL */
  tipo(config: TipoConfig): this {
    this._config = config;
    return this;
  }

  /**
   * Activa el vínculo de forma SÍNCRONA: instala listeners inmediatamente.
   * La máscara IMask se aplica en background (< 50 ms, daemon local).
   * Retorna Vinculo listo para encadenar .onValid() / .onInvalid() / etc.
   */
  bSet(): Vinculo {
    const config  = this._config ?? { base: "text" };
    const vinculo = new VinculoImpl(this.el, config, this.cliente);

    // Fetch máscara async — aplica antes de primera interacción del usuario
    this.cliente
      .llamar<PatronMascara>("bi18n.mask.pattern", { tipo: config, ctx_id: uuid() })
      .then(p => vinculo.aplicarMascara(p))
      .catch(() => { /* continúa sin máscara si el daemon no está disponible */ });

    return vinculo;
  }
}

// ── ValorBuilder ──────────────────────────────────────────────────────────────

/** Cadena lazy para transformar un valor crudo: formato, máscara, validación. */
class ValorBuilder {
  private _tipo:    TipoConfig | null = null;
  private _formato: string | null = null;
  private _mascara: string | null = null;

  constructor(
    private readonly raw:     unknown,
    private readonly cliente: Bi18nClient,
  ) {}

  tipo(c: TipoConfig): this      { this._tipo    = c; return this; }
  formato(f: string): this       { this._formato = f; return this; }
  mascara_display(m: string): this { this._mascara = m; return this; }

  /** Ejecuta la transformación y retorna el valor final como string. */
  async obtener(): Promise<string> {
    const valor = String(this.raw);

    if (this._formato) {
      const r = await this.cliente.llamar<{ formateado: string }>(
        "bi18n.format.value",
        { formato: this._formato, value: valor, ctx_id: uuid() }
      );
      return r.formateado;
    }

    if (this._mascara) {
      const r = await this.cliente.llamar<{ enmascarado: string }>(
        "bi18n.mask.pii",
        { mascara: this._mascara, value: valor, ctx_id: uuid() }
      );
      return r.enmascarado;
    }

    return valor;
  }

  /** Valida el valor sin binding de DOM. */
  async validar(): Promise<ResultadoValidacion> {
    return this.cliente.llamar<ResultadoValidacion>(
      "bi18n.validate.field",
      { tipo: this._tipo ?? { base: "text" },
        value: String(this.raw), required: false, ctx_id: uuid() }
    );
  }
}

// ── MostrarBuilder ─────────────────────────────────────────────────────────────

/** Renderiza un valor almacenado en un elemento de solo lectura. */
class MostrarBuilder {
  private _val:  unknown = "";
  private _tipo: TipoConfig | null = null;
  private _mask: string | null = null;
  private _fmt:  string | null = null;

  constructor(
    private readonly el:      Element,
    private readonly cliente: Bi18nClient,
  ) {}

  valor(v: unknown): this      { this._val  = v; return this; }
  tipo(c: TipoConfig): this    { this._tipo = c; return this; }
  mascara(m: string): this     { this._mask = m; return this; }
  formato(f: string): this     { this._fmt  = f; return this; }

  async render(): Promise<void> {
    const vb = new ValorBuilder(this._val, this.cliente);
    if (this._tipo) vb.tipo(this._tipo);
    if (this._fmt)  vb.formato(this._fmt);
    if (this._mask) vb.mascara_display(this._mask);
    this.el.textContent = await vb.obtener();
  }
}

// ── FormularioBuilder ──────────────────────────────────────────────────────────

type CbEnviar = (
  valores: Record<string, string>,
  meta:    { tiempo_ms: number }
) => Promise<void> | void;

/** Gestiona N vínculos de un formulario y el ciclo submit. */
class FormularioBuilder {
  private _cb:       CbEnviar | null = null;
  private _vinculos: Array<{ id: string; v: Vinculo }> = [];
  private _valores:  Record<string, string> = {};

  constructor(
    private readonly form:    HTMLFormElement,
    private readonly schema:  CampoSchema[],
    private readonly cliente: Bi18nClient,
  ) {}

  al_enviar(cb: CbEnviar): this { this._cb = cb; return this; }

  /** Activa todos los vínculos del formulario + listener de submit. */
  bSet(): FormularioBuilder {
    for (const entrada of this.schema) {
      const el  = resolverEl(`#${entrada.id}`);
      const v   = new CampoBuilder(el, this.cliente).tipo(entrada.config).bSet();
      const id  = entrada.id;

      v.onValid  (r  => { this._valores[id] = r.valor_normalizado; })
       .onInvalid(() => { delete this._valores[id]; });

      this._vinculos.push({ id, v });
    }
    this.form.addEventListener("submit", e => this._alEnviar(e));
    return this;
  }

  bUnSet(): void {
    this._vinculos.forEach(({ v }) => v.bUnSet());
    this._vinculos = [];
  }

  private async _alEnviar(e: Event): Promise<void> {
    e.preventDefault();
    const t0 = performance.now();
    const tiempo_ms = Math.round(performance.now() - t0);
    if (this._cb) await this._cb({ ...this._valores }, { tiempo_ms });
  }
}

// ── Bi18nSdk — fachada pública ─────────────────────────────────────────────────

/**
 * Fachada principal del SDK bi18n UI.
 * Instanciar una vez por página o componente raíz.
 *
 * @example
 *   const bi18n = new Bi18nSdk()
 *   bi18n.campo("#ci").tipo({ base: "CI", pais: "BO" }).bSet()
 *     .onValid(r  => console.log("válido", r.valor_normalizado))
 *     .onInvalid(r => console.error("inválido", r.errores))
 */
export class Bi18nSdk {
  private readonly cliente: Bi18nClient;

  constructor(url?: string) {
    this.cliente = new Bi18nClient(url);
  }

  /** Inicia un vínculo de campo. Continúa con .tipo({...}).bSet() */
  campo(selector: string | Element): CampoBuilder {
    return new CampoBuilder(resolverEl(selector), this.cliente);
  }

  /** Inicia una cadena de transformación de valor sin binding de DOM. */
  valor(raw: unknown): ValorBuilder {
    return new ValorBuilder(raw, this.cliente);
  }

  /** Inicia un renderizado de solo lectura en el elemento indicado. */
  mostrar(selector: string): MostrarBuilder {
    const el = document.querySelector(selector);
    if (!el) throw new Error(`bi18n: elemento no encontrado — "${selector}"`);
    return new MostrarBuilder(el, this.cliente);
  }

  /**
   * Renderiza un lote de valores en filas de tabla — una RPC por columna.
   * Añade `campo_display` a cada fila del array.
   */
  async mostrar_lote(
    filas:    Record<string, unknown>[],
    columnas: ConfigColumna[]
  ): Promise<void> {
    for (const fila of filas) {
      for (const col of columnas) {
        const vb = new ValorBuilder(String(fila[col.campo] ?? ""), this.cliente);
        if (col.tipo)    vb.tipo(col.tipo);
        if (col.formato) vb.formato(col.formato);
        if (col.mascara) vb.mascara_display(col.mascara);
        fila[`${col.campo}_display`] = await vb.obtener();
      }
    }
  }

  /** Inicia un vínculo de formulario completo. Continúa con .al_enviar(cb).bSet() */
  formulario(selector: string, schema: CampoSchema[]): FormularioBuilder {
    const el = document.querySelector(selector) as HTMLFormElement;
    if (!el) throw new Error(`bi18n: formulario no encontrado — "${selector}"`);
    return new FormularioBuilder(el, schema, this.cliente);
  }

  /** Cierra la conexión WebSocket. */
  cerrar(): void {
    this.cliente.cerrar();
  }
}
