"""
build_state.py — Build state tracker for SBOS agent construction.

Tracks per-agent PGE cycle results, CI gate status, and overall build phase progress.
Records to SKDATA trazas.ejecucion_pge and updates arboles.nodo estado.
"""

import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

from sbos_build_config import AgentBuildSpec, SBOS_AGENTS


@dataclass
class AgentBuildState:
    """Estado de construcción de un agente individual."""

    agent_name: str
    order: int
    perfil: str
    subfase: str
    estado: str = "en-construccion"  # en-construccion | operativo
    pge_cycles: int = 0
    pge_approved: int = 0
    pge_rejected: int = 0
    pge_escalated: bool = False
    ci_gate_passed: bool = False
    ci_gate_issues: list[str] = field(default_factory=list)
    last_pge_result: Optional[str] = None
    built_at: Optional[str] = None
    artifacts_dir: str = ""


class BuildTracker:
    """
    Rastreador del estado de construcción del proyecto SBOS completo.

    Persiste el estado en el workspace de Orquesta-Core-SBOS y
    actualiza SKDATA (arboles.nodo) al avanzar.
    """

    STATE_FILE = "build_state.json"

    def __init__(self, workspace: str):
        self.workspace = Path(workspace)
        self.agents: dict[str, AgentBuildState] = {}
        self._load_or_init()

    def _load_or_init(self):
        """Carga el estado desde disco o lo inicializa desde SBOS_AGENTS."""
        state_path = self.workspace / self.STATE_FILE
        if state_path.exists():
            data = json.loads(state_path.read_text())
            for name, d in data.get("agents", {}).items():
                spec = self._find_spec(name)
                if spec:
                    self.agents[name] = AgentBuildState(
                        agent_name=name,
                        order=spec.order,
                        perfil=spec.perfil,
                        subfase=spec.subfase,
                        **{k: v for k, v in d.items()
                           if k not in ("agent_name", "order", "perfil", "subfase")},
                    )
        else:
            for spec in SBOS_AGENTS:
                self.agents[spec.name] = AgentBuildState(
                    agent_name=spec.name,
                    order=spec.order,
                    perfil=spec.perfil,
                    subfase=spec.subfase,
                )
            self._sync_from_skdata()
            self._save()

    def _sync_from_skdata(self):
        """Sincroniza el estado inicial desde SKDATA (arboles.nodo)."""
        import subprocess
        try:
            r = subprocess.run(
                ["psql", "postgresql://root@localhost:5402/SKDATA", "-qtA",
                 "-c", (
                     "SELECT n.nombre, n.estado "
                     "FROM arboles.nodo n "
                     "JOIN arboles.arbol a ON a.id = n.arbol_id "
                     "JOIN proyectos.proyecto p ON p.id = a.proyecto_id "
                     "WHERE p.nombre = 'sbos'"
                 )],
                capture_output=True, text=True, timeout=10,
            )
            for line in r.stdout.strip().split("\n"):
                if "|" in line:
                    name, estado = line.split("|", 1)
                    if name in self.agents:
                        self.agents[name].estado = estado
        except Exception:
            pass  # psql no disponible — usar defaults

    def _find_spec(self, name: str) -> Optional[AgentBuildSpec]:
        for a in SBOS_AGENTS:
            if a.name == name:
                return a
        return None

    def _save(self):
        """Persiste el estado a disco."""
        data = {
            "updated_at": datetime.now().isoformat(),
            "agents": {
                name: {
                    "estado": s.estado,
                    "pge_cycles": s.pge_cycles,
                    "pge_approved": s.pge_approved,
                    "pge_rejected": s.pge_rejected,
                    "pge_escalated": s.pge_escalated,
                    "ci_gate_passed": s.ci_gate_passed,
                    "ci_gate_issues": s.ci_gate_issues,
                    "last_pge_result": s.last_pge_result,
                    "built_at": s.built_at,
                    "artifacts_dir": s.artifacts_dir,
                }
                for name, s in self.agents.items()
            },
        }
        state_path = self.workspace / self.STATE_FILE
        state_path.write_text(json.dumps(data, indent=2, ensure_ascii=False))

    def mark_pge_completed(self, agent_name: str, approved: bool,
                           cycle: int, issues: list[str] | None = None):
        """Registra la finalización de un ciclo PGE para un agente."""
        agent = self.agents.get(agent_name)
        if not agent:
            return
        agent.pge_cycles += 1
        if approved:
            agent.pge_approved += 1
            agent.last_pge_result = "APROBADO"
        else:
            agent.pge_rejected += 1
            agent.last_pge_result = "RECHAZADO"

        spec = self._find_spec(agent_name)
        if spec and agent.pge_rejected >= spec.max_iter:
            agent.pge_escalated = True

        self._save()

    def mark_ci_gate(self, agent_name: str, passed: bool, issues: list[str]):
        """Registra el resultado de CI gates para un agente."""
        agent = self.agents.get(agent_name)
        if not agent:
            return
        agent.ci_gate_passed = passed
        agent.ci_gate_issues = issues
        self._save()

    def mark_operativo(self, agent_name: str):
        """Marca un agente como operativo (construcción completada)."""
        agent = self.agents.get(agent_name)
        if not agent:
            return
        agent.estado = "operativo"
        agent.built_at = datetime.now().isoformat()
        self._save()

    def get_next_agent(self) -> Optional[AgentBuildSpec]:
        """Retorna el próximo agente que debe construirse (en orden, con dependencias satisfechas)."""
        for spec in sorted(SBOS_AGENTS, key=lambda a: a.order):
            state = self.agents.get(spec.name)
            if not state or state.estado != "en-construccion":
                continue
            # Verificar dependencias
            deps_ok = all(
                self.agents.get(self._find_spec_by_order(dep).name) is not None
                and self.agents[self._find_spec_by_order(dep).name].estado == "operativo"
                for dep in spec.depends_on
                if self._find_spec_by_order(dep)
            )
            if deps_ok:
                return spec
        return None

    def _find_spec_by_order(self, order: int) -> Optional[AgentBuildSpec]:
        for a in SBOS_AGENTS:
            if a.order == order:
                return a
        return None

    def subfase_progress(self, subfase: str) -> dict:
        """Retorna el progreso de una sub-fase."""
        agents_in = [a for a in SBOS_AGENTS if a.subfase == subfase]
        total = len(agents_in)
        operativos = sum(
            1 for a in agents_in
            if self.agents.get(a.name) and self.agents[a.name].estado == "operativo"
        )
        return {"subfase": subfase, "total": total, "operativos": operativos,
                "pendientes": total - operativos}

    def overall_progress(self) -> dict:
        """Retorna el progreso global de construcción."""
        total = len(SBOS_AGENTS)
        operativos = sum(
            1 for s in self.agents.values() if s.estado == "operativo"
        )
        return {
            "total_agentes": total,
            "operativos": operativos,
            "en_construccion": total - operativos,
            "subfases": {
                sf: self.subfase_progress(sf)
                for sf in ["2a", "2b", "2c"]
            },
        }
