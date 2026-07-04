# ADR-001 — BOS como Capa de Sistema Operativo

**Estado:** Aceptada
**Fecha:** 2026-05-15
**Decisor:** Ivan Villanueva (Arquitecto Líder)
**Ámbito:** SBOS IAM Installer — arquitectura del daemon `bos`

---

## Contexto

SBOS es un Sistema Operativo Empresarial Soberano. El daemon `bos` es el primer
proceso privilegiado que se instala en un Ubuntu virgen y desde ese momento actúa
como capa intermedia entre el kernel Linux y las aplicaciones de negocio.

En el modelo tradicional, el operador humano usa `sudo` para administrar el sistema
y herramientas externas (Terraform, Ansible, kubectl directo) para instalar software.
Esto dispersa la autoridad, complica la auditoría y viola el principio de soberanía:
el sistema debe gobernarse a sí mismo.

## Decisión

**BOS corre como root y actúa como capa de sistema operativo.**

1. BOS es el único proceso privilegiado que ejecuta comandos de sistema.
2. El operador humano interactúa con el sistema exclusivamente a través de `bosctl`
   o Core UI — nunca mediante `sudo` directamente.
3. Toda operación privilegiada queda registrada en `/var/log/bos/audit.log`.
4. BOS se auto-eleva durante el bootstrap usando credenciales de `bos-bootstrap.env`
   (archivo efímero, permisos 600, nunca versionado).

### Comandos de capa SO

| Comando BOS | Reemplaza a |
|---|---|
| `bosctl exec -- <cmd>` | `sudo <cmd>` |
| `bosctl ls <path>` | `sudo ls <path>` |
| `bosctl cat <path>` | `sudo cat <path>` |
| `bosctl systemctl <action>` | `sudo systemctl <action>` |

### Bootstrap automático

Al arrancar, BOS:
1. Carga `bos-bootstrap.env` (3 ubicaciones posibles)
2. Verifica que corre como root (`os.Getuid() == 0`)
3. Crea `/sys/fs/cgroup/k8s.io` si no existe
4. Detecta UID/GID del contenedor desde `/proc/self/uid_map`
5. Corrige ownership del cgroup
6. Ejecuta probe de escritura
7. Procede con la instalación autónoma del grafo completo de fichas

## Consecuencias

### Positivas
- **Soberanía total:** BOS es la única interfaz privilegiada del sistema.
- **Auditoría completa:** Cada operación root queda registrada con timestamp, usuario y comando.
- **Reproducibilidad:** El bootstrap es determinista y no depende de intervención humana.
- **Seguridad:** Las credenciales root existen solo en un .env efímero (permisos 600, excluido de git).

### Negativas
- **Punto único de fallo:** Si BOS no arranca, no hay forma privilegiada de administrar el sistema.
  Mitigación: watchdog con rollback automático al binario anterior.
- **Curva de aprendizaje:** El operador debe aprender `bosctl` en lugar de usar `sudo` directamente.
- **Acoplamiento:** Los task_catalog.sh dependen de que BOS les proporcione el entorno root.

### Riesgos mitigados
- **Password en .env:** El archivo tiene permisos 600, se excluye de git, y BOS limpia la
  variable de memoria después de usarla. En producción se usará Vault para el secreto root.
- **Log del password:** BOS NUNCA loguea `BOS_ROOT_PASSWORD`. El logger tiene un filtro
  explícito para eliminar contraseñas de los logs.

---

## Referencias
- SBOS-018-DAEMON-BOS §2 — "Control plane soberano del SBOS"
- SBOS-004-RULES — 14+1 principios
- P19 — BOS es el único instalador
- P23 — Source-first: corregir fuente, no contenedor

_SKULL · SBOS · ADR-001 · 2026-05-15_
