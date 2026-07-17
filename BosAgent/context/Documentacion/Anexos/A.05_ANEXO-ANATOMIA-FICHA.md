# Anexo A.05 — Anatomía Canónica de Ficha
## Estructura obligatoria de una ficha declarativa (SBOS-019 + servers.yml)

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ③ Server FICHAS
**Referencia:** [3.01 — Server FICHAS](../3.01_MANUAL-SERVER-FICHAS.md) · `servers.yml`

---

## 1. Estructura de archivos

```
servers/<ID>-<nombre>/<app>/
├── manifest.yml         ← ✅ OBLIGATORIO: identidad, deps, servidor, namespace, puerto, health
├── PROPOSITO.md         ← ✅ OBLIGATORIO: qué es, por qué existe, para qué sirve
├── task_catalog.sh      ← ✅ OBLIGATORIO: funciones <app>_install, _verify, _health, _repair, _remove
├── yaml_engine.yml      ← Opcional: fases declarativas
├── <app>.k8s.yml        ← Opcional: Deployment/StatefulSet
├── <app>.network        ← Opcional: NetworkPolicy
└── resources/           ← Opcional: sql/, config/, migrations/
```

## 2. Contrato de task_catalog.sh

```bash
<app>_install()   ← instala la aplicación
<app>_verify()    ← verifica que funciona (tests)
<app>_health()    ← health check rápido
<app>_repair()    ← repara sin reinstalar (idempotente)
<app>_remove()    ← desinstala limpiamente
```

## 3. Reglas

- Sin PROPOSITO.md → el Bibliotecario RECHAZA la ficha
- Función universal → vive en el motor (bos). Función específica → task_catalog.sh
- Nombre de ficha = nombre canónico del producto, no inventado por el daemon
- La versión vive en manifest.yml (identity.version), NUNCA en el nombre de carpeta
- Un objeto lógico = un archivo. Git lleva la historia, no `_v2`, `_final`

---

*SKULL · SBOS · BosAgent · Julio 2026*
