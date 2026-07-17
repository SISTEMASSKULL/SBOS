// ============================================================
// bauth_desktop · atomlang/vocabulario.dart
//
// Propósito: constantes de vocabulario AtomLang v1 para la UI del PAP.
//   ÚNICAMENTE valores que los menús contextuales del dashboard
//   necesitan mostrar como opciones. NO son usados para validación
//   (la validación la hace atomc en Rust contra PostgreSQL).
//
//   Cada constante refleja el vocabulario definido en:
//     A.46 §2 (EBNF) · A.45 §4 (operadores) · A.45 §6 (algoritmos)
//
// ⚠️  Estos sets NO son fuente de verdad — la fuente de verdad son
//     las tablas de catálogo en PostgreSQL (bauth.privilege_verb, etc.).
//     Si hay discrepancia, PostgreSQL prevalece.
//
// Estándar: XACML 3.0 (OASIS) · DOC-SBOS-001 N3.
// ============================================================

/// Verbos del vocabulario AtomLang (9 operadores base + ANY).
/// Refleja bauth.privilege_verb — consultar la BD para fuente autoritativa.
const Set<String> kVerbosUI = {
  'read',       'write',      'create',
  'delete',     'approve',    'execute',
  'export',     'delegate',   'configure',
  'audit',      'login',      'emit',
  'void',       'ANY',
};

/// Operadores de Condition según gramática EBNF (A.46 §2).
/// Exactamente 9 operadores — XACML 3.0 §A.7 + BETWEEN (composición).
const Set<String> kOperadoresUI = {
  '==', '!=', '>', '<', '>=', '<=',
  'IN', 'NOT_IN', 'BETWEEN',
};

/// Algoritmos de combinación XACML 3.0 §7.14 + extensión bAuth.
/// Exactamente 6 algoritmos (A.45 §6, A.46 §2 EBNF).
const Set<String> kAlgoritmosCombinacionUI = {
  'deny-overrides',
  'permit-overrides',
  'first-applicable',
  'deny-unless-permit',
  'permit-unless-deny',
  'aggregate-strictest',   // extensión bAuth para step-up concurrente
};

/// Decisiones de Effect XACML 3.0 §7.3.
/// Solo dos valores posibles — case-sensitive.
const Set<String> kDecisionesUI = {'Permit', 'Deny'};

/// Badges XACML del árbol según A.47 §2.1.
const Set<String> kBadgesXACML = {
  '[POLICYSET]',
  '[POLICY]',
  '[REGLA]',
  '[ATOM]',
  '[REGISTRO ESTRUCTURAL]',
};
