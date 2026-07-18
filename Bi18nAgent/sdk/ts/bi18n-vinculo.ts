/**
 * bi18n-vinculo.ts — VinculoImpl: gestión de máscara, listeners y eventos.
 * Propósito: implementa la interface Vinculo retornada por bSet().
 *   La máscara se aplica async en background — el daemon local responde en < 50 ms,
 *   antes de que el usuario haya tenido tiempo de interactuar.
 * Dependencias: bi18n-client, bi18n-tipos, IMask (global window.IMask)
 */

import { Bi18nClient } from "./bi18n-client.ts";
import type { TipoConfig, ResultadoValidacion, PatronMascara, Vinculo } from "./bi18n-tipos.ts";

// ── Helpers ──────────────────────────────────────────────────────────────────

function uuid(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

/** Lee el valor de un selector CSS — null si no existe */
function valorRef(selector: string): string | null {
  const el = document.querySelector(selector) as HTMLInputElement | null;
  return el ? el.value : null;
}

/** Añade los valores resueltos de validaciones cruzadas al params RPC */
function resolverCruzadas(config: TipoConfig, params: Record<string, unknown>): void {
  const campos: Array<[keyof TipoConfig, string]> = [
    ["confirmar",  "confirmar_valor"],
    ["distinto",   "distinto_valor"],
    ["mayor_que",  "mayor_que_valor"],
    ["menor_que",  "menor_que_valor"],
  ];
  for (const [campo, clave] of campos) {
    const selector = config[campo] as string | undefined;
    if (selector) {
      const v = valorRef(selector);
      if (v !== null) params[clave] = v;
    }
  }
}

/** Selecciona el mensaje correcto según estado y config */
function mensajeFinal(r: ResultadoValidacion, config: TipoConfig): string {
  const esWarn = Boolean((r.metadata as Record<string, unknown>)["advertencia"]);
  if (!r.valido) return config.msgError ?? r.errores[0] ?? r.mensaje;
  if (esWarn)    return config.msgWarn  ?? r.mensaje;
  return               config.msgOk    ?? r.mensaje;
}

// ── VinculoImpl ──────────────────────────────────────────────────────────────

/** Implementación interna de Vinculo */
export class VinculoImpl implements Vinculo {
  private mascara:       unknown = null;   // IMask.InputMask
  private tocado:        boolean = false;  // true tras primer blur
  private errorPrev:     boolean = false;  // re-valida en input si hay error activo
  private debounce:      ReturnType<typeof setTimeout> | null = null;

  private cbValid:   ((r: ResultadoValidacion) => void) | null = null;
  private cbInvalid: ((r: ResultadoValidacion) => void) | null = null;
  private cbWarn:    ((r: ResultadoValidacion) => void) | null = null;
  private cbError:   ((e: Error) => void)               | null = null;

  private readonly oyBlur:  EventListener;
  private readonly oyInput: EventListener;

  constructor(
    private readonly elemento: HTMLInputElement,
    private readonly config:   TipoConfig,
    private readonly cliente:  Bi18nClient,
  ) {
    this.oyBlur  = () => this._alBlur();
    this.oyInput = () => this._alInput();
    elemento.addEventListener("blur",  this.oyBlur);
    elemento.addEventListener("input", this.oyInput);
  }

  // ── Llamado async desde CampoBuilder tras bSet() ─────────────────────────
  aplicarMascara(patron: PatronMascara): void {
    if (!patron.usar_mascara) return;
    const IMask = (globalThis as Record<string, unknown>)["IMask"] as
      ((el: HTMLInputElement, opts: Record<string, unknown>) => unknown) | undefined;
    if (!IMask) return;

    const opts = this._opcionesImask(patron);
    this.mascara = IMask(this.elemento, opts);
  }

  // ── Interface Vinculo ─────────────────────────────────────────────────────

  get valor(): string { return this._valorActual(); }

  bUnSet(): void {
    this.elemento.removeEventListener("blur",  this.oyBlur);
    this.elemento.removeEventListener("input", this.oyInput);
    const m = this.mascara as { destroy?(): void } | null;
    if (m?.destroy) { m.destroy(); this.mascara = null; }
    if (this.debounce) clearTimeout(this.debounce);
  }

  onValid  (cb: (r: ResultadoValidacion) => void): Vinculo { this.cbValid   = cb; return this; }
  onInvalid(cb: (r: ResultadoValidacion) => void): Vinculo { this.cbInvalid = cb; return this; }
  onWarn   (cb: (r: ResultadoValidacion) => void): Vinculo { this.cbWarn    = cb; return this; }
  onError  (cb: (e: Error) => void):               Vinculo { this.cbError   = cb; return this; }

  // ── Internos ──────────────────────────────────────────────────────────────

  private _valorActual(): string {
    const m = this.mascara as { unmaskedValue?: string } | null;
    return m?.unmaskedValue !== undefined ? m.unmaskedValue : this.elemento.value;
  }

  private async _alBlur(): Promise<void> {
    this.tocado = true;
    await this._validar();
  }

  private _alInput(): void {
    if (this.tocado && this.errorPrev) {
      if (this.debounce) clearTimeout(this.debounce);
      this.debounce = setTimeout(() => this._validar(), 300);
    }
  }

  private async _validar(): Promise<void> {
    const params: Record<string, unknown> = {
      tipo:     this.config,
      value:    this._valorActual(),
      required: this.config.requerido ?? false,
      ctx_id:   uuid(),
    };
    resolverCruzadas(this.config, params);

    try {
      const r = await this.cliente.llamar<ResultadoValidacion>(
        "bi18n.validate.field", params
      );
      const esWarn = Boolean((r.metadata as Record<string, unknown>)["advertencia"]);
      const c: ResultadoValidacion = { ...r, mensaje: mensajeFinal(r, this.config) };

      this.errorPrev = !r.valido;

      if (!r.valido)  this.cbInvalid?.(c);
      else if (esWarn) this.cbWarn?.(c);
      else             this.cbValid?.(c);
    } catch (e) {
      this.cbError?.(e instanceof Error ? e : new Error(String(e)));
    }
  }

  private _opcionesImask(p: PatronMascara): Record<string, unknown> {
    const o: Record<string, unknown> = { ...p.opciones };
    if (p.motor === "Pattern" && p.patron) o["mask"] = p.patron;
    else if (p.motor === "Date")           o["mask"] = Date;
    else if (p.motor === "Number")         o["mask"] = Number;
    return o;
  }
}
