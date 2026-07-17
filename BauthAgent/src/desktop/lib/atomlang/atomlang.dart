// ============================================================
// bauth_desktop · atomlang/atomlang.dart
//
// Propósito: barrel de exportación del módulo AtomLang (PAP).
//   El dashboard Flutter es el Policy Administration Point (PAP):
//   edita el árbol SOURCE visualmente y serializa a .atm.yaml.
//
//   La validación, normalización y compilación las hace atomc
//   (Rust, BauthAgent/tools/atomc/), NO el dashboard.
//
// Módulos:
//   vocabulario.dart — constantes de UI (verbos, operadores, algoritmos)
//
// Estándar: DOC-SBOS-001 N3 · A.45 §2.2 (PAP/PDP/PEP/PIP).
// ============================================================

export 'vocabulario.dart';
