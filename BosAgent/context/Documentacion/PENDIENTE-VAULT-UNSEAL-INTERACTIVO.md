# PENDIENTE — bosctl vault unseal interactivo

**Estado:** EN SUSPENSE — implementar solo cuando el instalador completo funcione de punta a punta.

**Qué es:** Comando `bosctl vault unseal` que pausa la saga de instalación y solicita
los fragmentos de unseal a los custodios por teclado (entrada enmascarada), sin leer
ningún archivo del disco.

**Cuándo implementar:** Después de que el operador ejecute la instalación completa en
la VPS de prueba y todo funcione correctamente. El vault unseal interactivo es la
última pieza del wizard para una instalación profesional.

**Comportamiento esperado:**
```
BOS: ⚠️  ACCIÓN REQUERIDA — CUSTODIOS DE VAULT
     Se necesitan 3 de 5 fragmentos para continuar.

     Custodio 1 — ingrese su fragmento: ████████
     Custodio 2 — ingrese su fragmento: ████████
     Custodio 3 — ingrese su fragmento: ████████

BOS: ✅ Vault desenmascarado. Continuando instalación...
```

**Archivos a modificar cuando se implemente:**
- `cmd/bosctl/vault.go` — nuevo subcomando `bosctl vault unseal` con `term.ReadPassword`
- `internal/installer/saga.go` — paso de saga `StepVaultUnseal` que llama al prompt
- `servers/S02/vault-unsealer/task_catalog.sh` — agregar modo `--interactive` vs `--dev-mode`

**Regla:** el modo archivo (`/etc/bos/vault-init-keys.json`) queda solo para CI/test
con flag explícito `--dev-mode`. El modo por defecto en producción es el prompt interactivo.
