/**
 * bi18n-client.ts — Cliente WebSocket JSON-RPC 2.0 para el daemon bi18n.
 * Propósito: capa de transporte con reconexión automática y cola de pendientes.
 * Depende de: Web API WebSocket (browser / Node >= 22)
 * Especificación: 1.04 Parte II §6
 */

const WS_URL_DEFECTO = "ws://127.0.0.1:9454";
const TIMEOUT_MS     = 5_000;
const REINTENTO_BASE = 500;   // ms — base para backoff exponencial
const MAX_REINTENTOS = 8;

/** Pendiente de respuesta: una promesa por cada llamada en vuelo */
interface Pendiente {
  resolve: (value: unknown) => void;
  reject:  (reason: Error)  => void;
  timer:   ReturnType<typeof setTimeout>;
}

/** Cliente WebSocket JSON-RPC 2.0 con reconexión automática. */
export class Bi18nClient {
  private ws:         WebSocket | null = null;
  private pendiente:  Map<number, Pendiente> = new Map();
  private id:         number = 0;
  private reintentos: number = 0;
  private cola:       Array<string> = [];          // mensajes en espera de conexión
  private conectando: boolean = false;

  constructor(private readonly url: string = WS_URL_DEFECTO) {}

  /** Conecta al daemon. Se llama automáticamente en la primera llamada. */
  conectar(): Promise<void> {
    if (this.ws?.readyState === WebSocket.OPEN) return Promise.resolve();
    if (this.conectando) return new Promise(r => setTimeout(r, 100));

    this.conectando = true;
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(this.url);
      ws.onopen = () => {
        this.ws         = ws;
        this.reintentos = 0;
        this.conectando = false;
        this.cola.forEach(m => ws.send(m));
        this.cola = [];
        resolve();
      };
      ws.onmessage = e => this._onMensaje(e.data);
      ws.onerror   = () => { this.conectando = false; reject(new Error("bi18n WS error")); };
      ws.onclose   = () => this._reconectar();
    });
  }

  /** Llama a un método JSON-RPC 2.0 y retorna el `result`. */
  async llamar<T = unknown>(metodo: string, params: Record<string, unknown>): Promise<T> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      await this.conectar().catch(() => { /* reintenta vía cola */ });
    }
    const id  = ++this.id;
    const msg = JSON.stringify({ jsonrpc: "2.0", id, method: metodo, params });

    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendiente.delete(id);
        reject(new Error(`bi18n: timeout en "${metodo}" (${TIMEOUT_MS} ms)`));
      }, TIMEOUT_MS);

      this.pendiente.set(id, { resolve: resolve as (v: unknown) => void, reject, timer });

      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(msg);
      } else {
        this.cola.push(msg);
      }
    });
  }

  /** Cierra la conexión limpiamente. */
  cerrar(): void {
    this.ws?.close();
    this.ws = null;
    this.pendiente.forEach(p => { clearTimeout(p.timer); p.reject(new Error("cerrado")); });
    this.pendiente.clear();
  }

  private _onMensaje(raw: string): void {
    let resp: { id?: number; result?: unknown; error?: { message: string } };
    try { resp = JSON.parse(raw); } catch { return; }
    if (resp.id === undefined) return;
    const p = this.pendiente.get(resp.id);
    if (!p) return;
    clearTimeout(p.timer);
    this.pendiente.delete(resp.id);
    if (resp.error) {
      p.reject(new Error(`bi18n RPC [${resp.id}]: ${resp.error.message}`));
    } else {
      p.resolve(resp.result);
    }
  }

  private _reconectar(): void {
    if (this.reintentos >= MAX_REINTENTOS) return;
    const delay = REINTENTO_BASE * Math.pow(2, this.reintentos++);
    setTimeout(() => this.conectar().catch(() => { /* reintento siguiente */ }), delay);
  }
}
