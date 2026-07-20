// ============================================================
// bauth_desktop · datos/atomlang_validador_datos.dart
//
// Propósito: analizador/linter del árbol AtomLang.
//   No es un transformador pasivo — es un VERIFICADOR de reglas del lenguaje.
//   Recorre el árbol normalizado, detecta violaciones de las normas 2.13, 2.14
//   y Anexo A.47, e inyecta nodos TipoNodo.diagnostico como primeros hijos
//   de cada nodo infractor. El resultado es un árbol anotado donde cualquier
//   incumplimiento aparece inline junto al nodo que lo comete, igual que un
//   linter de código fuente muestra errores donde ocurren.
//
// Entrada:  árbol normalizado (snake_case canónico)
// Salida:   árbol anotado — misma estructura + nodos de diagnóstico inyectados
//
// Reglas implementadas:
//   ATOMC-E-005  verb_id obligatorio en átomo independiente    [2.13 §4.2 · A.47 §9]
//   ATOMC-E-013  effect.decision solo Permit o Deny           [2.13 §4.4 · XACML 3.0 §7.3]
//   ATOMC-E-031  combining_algorithm faltante en contenedor   [2.14 §3.2 · A.47 §2.3]
//   ATOMC-E-032  combining_algorithm en nodo no-contenedor    [2.14 §3.1 · XACML 3.0 §7.14]
//   ATOMC-W-041  AP1: literal numérico en nombre de átomo     [2.14 §10 AP1]
//
// Dependencias: datos/rol_template_datos (NodoTemplate · TipoNodo).
// Estándar: 2.13 §4 · 2.14 §3/§10 · A.47 §2/§9 · DOC-SBOS-001 N3.
// ============================================================

import 'rol_template_datos.dart';

// ──── Modelo de diagnóstico ───────────────────────────────────

/// Severidad de la violación detectada.
enum SeveridadDiagnostico {
  error, // ATOMC-E-xxx: viola regla obligatoria del lenguaje
  aviso, // ATOMC-W-xxx: viola recomendación (anti-patrón)
}

/// Un diagnóstico generado por el analizador sobre un nodo del árbol.
class DiagnosticoAtomLang {
  /// Código de error: ATOMC-E-005, ATOMC-W-041, etc.
  final String codigo;

  /// Descripción legible de la violación.
  final String mensaje;

  final SeveridadDiagnostico severidad;

  /// Sección del manual que define la regla violada.
  final String referencia;

  const DiagnosticoAtomLang(
      this.codigo, this.mensaje, this.severidad, this.referencia);
}

// ──── Utilidades de árbol ─────────────────────────────────────

/// Cuenta todos los nodos de diagnóstico en el subárbol (errores + avisos).
/// Útil para badges de conteo en nodos colapsados.
int contarDiagnosticosEnSubarbol(NodoTemplate n) =>
    (n.tipo == TipoNodo.diagnostico ? 1 : 0) +
    n.hijos.fold(0, (s, h) => s + contarDiagnosticosEnSubarbol(h));

/// Devuelve el primer hijo con la clave dada, o null.
NodoTemplate? _hijoConClave(NodoTemplate n, String clave) =>
    n.hijos.where((NodoTemplate h) => h.clave == clave).firstOrNull;

/// Rótulo legible del tipo de nodo para mensajes de error.
String _rotuloDeTipo(TipoNodo t) => switch (t) {
      TipoNodo.dominio   => 'DOMINIO',
      TipoNodo.bloque    => 'BLOQUE',
      TipoNodo.politica  => 'POLÍTICA',
      TipoNodo.regla     => 'REGLA',
      TipoNodo.objeto    => 'OBJETO',
      TipoNodo.lista     => 'LISTA',
      _                  => t.name.toUpperCase(),
    };

// ──── Generador de nodo diagnóstico ───────────────────────────

/// Convierte un diagnóstico en un NodoTemplate de tipo `diagnostico`.
/// La clave muestra el código de error; el valor muestra la referencia.
/// El PanelHelp muestra el mensaje completo al seleccionarlo.
NodoTemplate _nodoDesde(DiagnosticoAtomLang d) {
  final icono = d.severidad == SeveridadDiagnostico.error ? '✕' : '⚠';
  return NodoTemplate(
    '$icono ${d.codigo}',
    TipoNodo.diagnostico,
    valor: d.referencia,
    help: '${d.codigo}: ${d.mensaje}\n\nReferencia: ${d.referencia}',
  );
}

// ──── Motor de reglas ─────────────────────────────────────────

/// Evalúa un nodo contra todas las reglas AtomLang y devuelve los diagnósticos.
/// [tipoPadre]: tipo del nodo padre — determina si este nodo es átomo independiente.
List<DiagnosticoAtomLang> _evaluarReglas(
    NodoTemplate n, TipoNodo? tipoPadre) {
  final List<DiagnosticoAtomLang> diags = [];

  // ── ATOMC-E-005 ──────────────────────────────────────────────
  // verb_id obligatorio en todo átomo que sea hijo directo de POLÍTICA.
  // Un átomo dentro de una REGLA hereda el verbo del contexto: no aplica.
  // Referencia: 2.13 §4.2 · A.47 §9 (Action del Target XACML).
  if (n.tipo == TipoNodo.evaluacion && tipoPadre == TipoNodo.politica) {
    if (!n.hijos.any((NodoTemplate h) => h.clave == 'verbo')) {
      diags.add(const DiagnosticoAtomLang(
        'ATOMC-E-005',
        'verb_id faltante — todo átomo hijo directo de POLÍTICA debe declarar '
            '"verbo:" (Action del Target XACML). Sin él, el átomo se aplica a '
            'CUALQUIER operación, violando el principio de mínimo privilegio.',
        SeveridadDiagnostico.error,
        '2.13 §4.2 · A.47 §9 · XACML 3.0 §7.6',
      ));
    }
  }

  // ── ATOMC-E-031 ──────────────────────────────────────────────
  // combining_algorithm obligatorio en todo contenedor XACML con átomos.
  // Aplica a: DOMINIO (PolicySet), BLOQUE (PolicySet), POLÍTICA (Policy).
  // Referencia: 2.14 §3.2 · A.47 §2.3 · XACML 3.0 §7.14.
  if (n.tipo == TipoNodo.dominio ||
      n.tipo == TipoNodo.bloque ||
      n.tipo == TipoNodo.politica) {
    final nEvals =
        n.hijos.where((NodoTemplate h) => h.tipo == TipoNodo.evaluacion).length;
    if (nEvals >= 1 && !n.hijos.any((NodoTemplate h) => h.clave == 'combining_algorithm')) {
      diags.add(DiagnosticoAtomLang(
        'ATOMC-E-031',
        'combining_algorithm faltante — ${_rotuloDeTipo(n.tipo)} con $nEvals '
            'átomo(s) debe declarar el algoritmo XACML 3.0 de combinación '
            '(deny-overrides · permit-overrides · first-applicable · '
            'aggregate-strictest). Sin él, el PDP no puede resolver conflictos.',
        SeveridadDiagnostico.error,
        '2.14 §3.2 · A.47 §2.3 · XACML 3.0 §7.14',
      ));
    }
  }

  // ── ATOMC-E-032 ──────────────────────────────────────────────
  // combining_algorithm es inválido en nodos que no son contenedores XACML.
  // REGLA, OBJETO y LISTA no producen Decision: no tienen combining_algorithm.
  // Referencia: 2.14 §3.1 · XACML 3.0 §7.14.
  if (n.tipo == TipoNodo.regla ||
      n.tipo == TipoNodo.objeto ||
      n.tipo == TipoNodo.lista) {
    if (n.hijos.any((NodoTemplate h) => h.clave == 'combining_algorithm')) {
      diags.add(DiagnosticoAtomLang(
        'ATOMC-E-032',
        'combining_algorithm inválido en ${_rotuloDeTipo(n.tipo)} — '
            'solo DOMINIO, BLOQUE y POLÍTICA pueden declarar algoritmo de '
            'combinación. REGLA usa conectores lógicos (op_lógico), OBJETO y '
            'LISTA son datos estructurados sin Decision XACML.',
        SeveridadDiagnostico.error,
        '2.14 §3.1 · XACML 3.0 §7.14',
      ));
    }
  }

  // ── ATOMC-E-013 ──────────────────────────────────────────────
  // effect.decision debe ser exactamente "Permit" o "Deny" (case-sensitive).
  // Referencia: 2.13 §4.4 · XACML 3.0 §7.3.
  if (n.clave == 'effect') {
    final decision = _hijoConClave(n, 'decision');
    if (decision == null) {
      diags.add(const DiagnosticoAtomLang(
        'ATOMC-E-013',
        'effect sin "decision" — todo nodo effect XACML requiere un hijo '
            '"decision" con valor "Permit" o "Deny". Sin este hijo el PDP '
            'no puede emitir la decisión de acceso.',
        SeveridadDiagnostico.error,
        '2.13 §4.4 · XACML 3.0 §7.3',
      ));
    } else if (decision.valor != 'Permit' && decision.valor != 'Deny') {
      diags.add(DiagnosticoAtomLang(
        'ATOMC-E-013',
        'decision inválida "${decision.valor}" — XACML 3.0 §7.3 solo admite '
            '"Permit" o "Deny" (sensible a mayúsculas). Valores como "PERMIT", '
            '"deny", "Allow" o "Block" son rechazados por el PDP.',
        SeveridadDiagnostico.error,
        '2.13 §4.4 · XACML 3.0 §7.3',
      ));
    }
  }

  // ── ATOMC-W-041 ──────────────────────────────────────────────
  // AP1: el nombre de un átomo NO debe contener literales de umbral monetario.
  // Detecta: "> N" (comparación literal), "N%" (porcentaje), "N_bob/usd/eur/btc".
  // Excluye: nombres de estándares (x509, rfc_NNNN, aal2, sha256, pkcs12, etc.).
  // Los umbrales monetarios son parámetros de configuración, no constantes.
  // Referencia: 2.14 §10 AP1.
  if (n.tipo == TipoNodo.evaluacion) {
    final nombre = n.clave;
    final tieneUmbral =
        RegExp(r'[><=]\s*\d+|\d+\s*%|\d{4,}_(bob|usd|eur|btc)').hasMatch(nombre);
    final esEstandar =
        RegExp(r'rfc_?\d|x_?509|pkcs\d|sha_?\d|aes_?\d|aal[0-9]|oauth\d|ecdsa|ed25519|chacha').hasMatch(nombre);
    if (tieneUmbral && !esEstandar) {
      diags.add(DiagnosticoAtomLang(
        'ATOMC-W-041',
        'AP1: literal de umbral en nombre de átomo "$nombre" — los umbrales '
            'monetarios y porcentajes deben referenciarse como '
            '@bauth_config_param.<clave>, nunca como literales en el nombre. '
            'Si el umbral cambia, el nombre queda desactualizado.',
        SeveridadDiagnostico.aviso,
        '2.14 §10 AP1',
      ));
    }
  }

  return diags;
}

// ──── Transformador principal ─────────────────────────────────

/// Anota recursivamente el árbol: inyecta nodos TipoNodo.diagnostico
/// como primeros hijos de cada nodo que viola reglas AtomLang.
///
/// [tipoPadre]: tipo del nodo padre, necesario para detectar átomos
///   independientes (ATOMC-E-005). Null en la raíz.
///
/// Produce un árbol paralelo — el árbol original no se modifica.
NodoTemplate anotarNodo(NodoTemplate n, {TipoNodo? tipoPadre}) {
  final nodosError =
      _evaluarReglas(n, tipoPadre).map(_nodoDesde).toList();
  final hijosAnotados =
      n.hijos.map((NodoTemplate h) => anotarNodo(h, tipoPadre: n.tipo)).toList();
  return NodoTemplate(
    n.clave,
    n.tipo,
    valor: n.valor,
    help: n.help,
    opciones: n.opciones,
    hijos: [...nodosError, ...hijosAnotados],
  );
}
