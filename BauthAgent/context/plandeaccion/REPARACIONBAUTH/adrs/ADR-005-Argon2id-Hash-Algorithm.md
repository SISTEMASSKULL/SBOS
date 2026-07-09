# ADR-005 — Argon2id como Algoritmo de Hashing Obligatorio

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

NIST SP 800-63B Rev.4 (2024) y OWASP ASVS 2.4.3 recomiendan Argon2id como algoritmo de hashing de contraseñas. Los algoritmos legacy (SHA1, MD5, bcrypt) son vulnerables a ataques con hardware moderno (GPU, FPGA, ASIC). PBKDF2-SHA256 requiere 310,000+ iteraciones para ser seguro, haciendo la verificación lenta.

## Decisión

**Argon2id como algoritmo exclusivo de hashing de contraseñas para nuevos roles.**

Parámetros diferenciados por criticidad del tier:
- SU: t=5 (time cost), m=128MB (memory), p=2 (parallelism)
- SYS: t=3, m=64MB, p=2
- BIZ_N3-N5: t=3, m=64MB, p=2
- BIZ_N1-N2: t=2, m=32MB, p=1
- EXT_N0: t=2, m=32MB, p=1

Algoritmos deprecados: SHA1, MD5, bcrypt. PBKDF2-SHA256 solo para verificación de hashes legacy durante migración.

## Alternativas

| Alternativa | Problema |
|------------|---------|
| PBKDF2-SHA256 | 310K iteraciones = lento en verificación. Vulnerable a GPU/FPGA. NIST ya no lo recomienda para nuevas implementaciones. |
| bcrypt | Límite de 72 bytes de input. Vulnerable a FPGA. No memory-hard. |
| scrypt | Menos analizado que Argon2id. Parámetros más difíciles de configurar correctamente. |

## Consecuencias

- Argon2id es memory-hard: requiere 32-128MB por hash, haciendo ataques GPU/ASIC prohibitivamente costosos
- Parámetros por tier: roles de alto privilegio tienen hashes más costosos de atacar
- Migración transparente: al hacer login, si el hash es legacy → verificar con algoritmo antiguo → re-hash con Argon2id

## Referencias
- NIST SP 800-63B Rev.4 (2024) §5.1.1.2
- OWASP ASVS 4.0.3 §2.4.3
- Argon2 RFC 9106
