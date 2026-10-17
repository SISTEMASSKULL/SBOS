#!/usr/bin/env python3
"""Agrega auto_install: true a manifests que no lo tienen."""
import re
from pathlib import Path

SERVERS_DIR = Path("/opt/skull/orquestador/proyectos/SBOS/servers")

# Fichas que deben quedar en auto_install: false (tools opcionales, no core)
SKIP_AUTO = {
    "k6", "goss", "trivy", "compliance-check", "container-watchdog",
    "bareos", "k8s-upgrader", "sbos-fichas-migrator",
    "bcompass-svc", "cert-rotation", "network-validator",
    "sbos-bootstrap-hard",  # instalación inicial manual
}

modified = []
skipped = []
already = []

for manifest in SERVERS_DIR.rglob("manifest.yml"):
    if "_descartadas" in str(manifest):
        continue
    content = manifest.read_text()

    # Ya tiene auto_install
    if "auto_install" in content:
        already.append(manifest)
        continue

    # Obtener ID
    m = re.search(r'^\s+id:\s+"?([^"\n]+)"?', content, re.MULTILINE)
    ficha_id = m.group(1).strip() if m else manifest.parent.name

    value = "false" if ficha_id in SKIP_AUTO else "true"

    # Insertar en bloque governance: si existe
    if "governance:" in content:
        new_content = re.sub(
            r'(governance:\s*\n)',
            f"\\1  auto_install: {value}\n  requires_approval: false\n",
            content, count=1
        )
    else:
        # Agregar bloque governance: antes de health: o al final
        if "health:" in content:
            new_content = content.replace(
                "health:",
                f"governance:\n  auto_install: {value}\n  requires_approval: false\n\nhealth:",
                1
            )
        else:
            new_content = content + f"\ngovernance:\n  auto_install: {value}\n  requires_approval: false\n"

    if new_content != content:
        manifest.write_text(new_content)
        if value == "true":
            modified.append(ficha_id)
        else:
            skipped.append(ficha_id)

print(f"auto_install: true  → {len(modified)} fichas")
print(f"auto_install: false → {len(skipped)} fichas")
print(f"Ya tenían auto_install: {len(already)}")
if modified:
    print("\nActivadas:")
    for f in sorted(modified):
        print(f"  {f}")
