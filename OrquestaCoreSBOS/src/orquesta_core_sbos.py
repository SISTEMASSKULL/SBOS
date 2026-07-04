#!/usr/bin/env python3
"""
orquesta_core_sbos.py — SBOS Build Coordinator.

Motor de construcción para el proyecto SBOS. Coordina la ejecución
del pipeline PGE para los 11 agentes en 3 sub-fases, aplicando
MAX_ITER, CI gates poliglotas, y registrando resultados.

Usage:
    python orquesta_core_sbos.py status       # Mostrar progreso
    python orquesta_core_sbos.py next         # Mostrar próximo agente
    python orquesta_core_sbos.py validate N   # Ejecutar CI gates para agente N
"""

import sys
from pathlib import Path

from sbos_build_config import (
    SBOS_AGENTS, get_agent, get_agents_by_subfase,
    get_ci_gates, max_iter_for,
)
from build_state import BuildTracker
from ci_gates import run_ci_gates


WORKSPACE = str(Path(__file__).resolve().parent.parent)
TRACKER = BuildTracker(WORKSPACE)


def cmd_status():
    """Muestra el estado global de construcción."""
    p = TRACKER.overall_progress()
    print(f"SBOS Build Status — {p['operativos']}/{p['total_agentes']} operativos")
    print()
    for a in sorted(SBOS_AGENTS, key=lambda x: x.order):
        s = TRACKER.agents.get(a.name)
        icon = "✅" if s and s.estado == "operativo" else "⬜"
        ci = "CI✓" if s and s.ci_gate_passed else ""
        pge = f"PGE:{s.pge_approved}/{s.pge_cycles}" if s and s.pge_cycles > 0 else ""
        print(f"  [{a.order:2d}] {icon} {a.name:25s} {a.perfil:12s} {a.subfase}  {pge} {ci}")

    print()
    for sf in ["2a", "2b", "2c"]:
        sp = TRACKER.subfase_progress(sf)
        bar = "█" * sp["operativos"] + "░" * sp["pendientes"]
        print(f"  Sub-fase {sf}: {bar} {sp['operativos']}/{sp['total']}")

    print(f"\n  Próximo: {_next_agent_name()}")


def cmd_next():
    """Muestra el próximo agente a construir."""
    name = _next_agent_name()
    if name is None:
        print("Todos los agentes están operativos. Construcción completa.")
        return
    spec = get_agent(name)
    if spec is None:
        return
    state = TRACKER.agents.get(name)
    print(f"Próximo agente: {spec.name} (orden {spec.order}, {spec.perfil}, {spec.language})")
    print(f"  Componentes: {', '.join(spec.components) if spec.components else 'N/A'}")
    print(f"  MAX_ITER: {spec.max_iter}")
    print(f"  CI gates ({spec.language}):")
    for stage, cmd in get_ci_gates(spec.language).items():
        if stage != "coverage_min":
            print(f"    - {stage}: {cmd}")
    if spec.depends_on:
        deps = [a.name for a in SBOS_AGENTS if a.order in spec.depends_on]
        print(f"  Depende de: {', '.join(deps)}")
    print(f"  Gate: {spec.gate_criteria}")
    print(f"  Workspace: {spec.workspace}")
    if state:
        print(f"  PGE cycles: {state.pge_approved} approved / {state.pge_rejected} rejected")


def cmd_validate(order: int):
    """Ejecuta CI gates para un agente específico."""
    spec = next((a for a in SBOS_AGENTS if a.order == order), None)
    if spec is None:
        print(f"Agente con orden {order} no encontrado.")
        return
    ws = spec.workspace
    if not Path(ws).exists():
        print(f"Workspace no existe: {ws}")
        print("CI gates requieren código generado en el workspace.")
        return

    print(f"Ejecutando CI gates para {spec.name} ({spec.language})...")
    result = run_ci_gates(spec.language, ws)
    TRACKER.mark_ci_gate(spec.name, result.passed, result.issues)

    print(f"  Resultado: {result.summary}")
    for stage, ok in result.stages.items():
        icon = "✅" if ok else "❌"
        print(f"    {icon} {stage}")
    if result.issues:
        print("  Issues:")
        for issue in result.issues[:10]:
            print(f"    - {issue[:200]}")


def _next_agent_name() -> str | None:
    next_agent = TRACKER.get_next_agent()
    return next_agent.name if next_agent else None


# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════

COMMANDS = {
    "status": cmd_status,
    "next": cmd_next,
}


def main():
    if len(sys.argv) < 2:
        cmd_status()
        return

    cmd = sys.argv[1]

    if cmd in COMMANDS:
        COMMANDS[cmd]()
    elif cmd == "validate" and len(sys.argv) >= 3:
        try:
            cmd_validate(int(sys.argv[2]))
        except ValueError:
            print(f"Orden inválido: {sys.argv[2]}")
    elif cmd == "agents":
        for a in SBOS_AGENTS:
            print(f"  [{a.order:2d}] {a.name:25s} {a.perfil:12s} {a.language:8s} MAX_ITER={a.max_iter}")
    elif cmd == "config":
        print(f"Agentes: {len(SBOS_AGENTS)}")
        print(f"Lenguajes: {', '.join(sorted(set(a.language for a in SBOS_AGENTS)))}")
        print(f"MAX_ITER map: {max_iter_for}")
        print(f"Sub-fase 2a: {len(get_agents_by_subfase('2a'))} agentes")
        print(f"Sub-fase 2b: {len(get_agents_by_subfase('2b'))} agentes")
        print(f"Sub-fase 2c: {len(get_agents_by_subfase('2c'))} agentes")
    else:
        print(f"Uso: {sys.argv[0]} [status|next|validate N|agents|config]")


if __name__ == "__main__":
    main()
