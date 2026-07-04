"""
sbos_build_config.py — Configuración de construcción del proyecto SBOS.

Define el orden de construcción de los 11 agentes en 3 sub-fases,
los CI gates por lenguaje, y MAX_ITER por tipo de artefacto.
"""

from dataclasses import dataclass, field
from typing import Optional

# ═══════════════════════════════════════════════════════════════
# MAX_ITER por tipo de artefacto (ADR-026 + SBOS extensions)
# ═══════════════════════════════════════════════════════════════

MAX_ITER_MAP = {
    "ai_doc": 2,
    "manifest": 3,
    "arbol": 3,
    "codigo_dominio": 5,
    "ddl_sql": 3,
    "config_yaml": 3,
    "test": 3,
    "docs": 7,
}

MAX_ITER_DEFAULT = 5

# ═══════════════════════════════════════════════════════════════
# CI Gates por lenguaje
# ═══════════════════════════════════════════════════════════════

CI_GATES = {
    "rust": {
        "format": "cargo fmt --check",
        "lint": "cargo clippy -- -D warnings",
        "check": "cargo check",
        "test": "cargo test",
        "audit": "cargo audit",
        "build": "cargo build --release",
        "coverage_min": 85,
    },
    "go": {
        "format": "gofmt -l .",
        "lint": "golangci-lint run",
        "vet": "go vet ./...",
        "test": "go test -race -count=1 ./...",
        "build": "go build -ldflags='-s -w' -o bin/",
        "coverage_min": 80,
    },
    "java": {
        "format": "mvn spotless:check",
        "lint": "mvn checkstyle:check",
        "test": "mvn test",
        "build": "mvn package -DskipTests",
        "audit": "mvn dependency-check:check",
        "coverage_min": 70,
    },
    "python": {
        "format": "ruff format --check .",
        "lint": "ruff check .",
        "typecheck": "mypy src/",
        "test": "pytest --cov --cov-fail-under=85",
        "coverage_min": 85,
    },
    "bash": {
        "lint": "shellcheck *.sh",
        "test": "bats tests/",
        "coverage_min": 80,
    },
    "dart": {
        "format": "dart format --output=none .",
        "analyze": "flutter analyze",
        "test": "flutter test --coverage",
        "coverage_min": 70,
    },
    "yaml": {
        "lint": "yamllint .",
        "schema": "check-jsonschema --schemafile schema.json",
        "coverage_min": 100,
    },
    "sql": {
        "lint": "sqlfluff lint",
        "test": "pgTAP tests/",
        "coverage_min": 100,
    },
}


@dataclass
class AgentBuildSpec:
    """Especificación de construcción para un agente del árbol SBOS."""

    name: str
    order: int
    perfil: str  # staff, nativo, fundacional, dominio
    subfase: str  # 2a, 2b, 2c
    language: str
    max_iter: int = 5
    gate_criteria: str = ""
    components: list[str] = field(default_factory=list)
    depends_on: list[int] = field(default_factory=list)
    workspace: str = ""


# ═══════════════════════════════════════════════════════════════
# Orden de construcción (arquitectura-inicial.md §6 + partitura-maestra.md §4)
# ═══════════════════════════════════════════════════════════════

SBOS_AGENTS: list[AgentBuildSpec] = [
    # Sub-fase 2a — Staff + Fundacionales P0
    AgentBuildSpec(
        name="Compositor-SBOS",
        order=1, perfil="staff", subfase="2a",
        language="python", max_iter=3,
        gate_criteria="Fase A/B/C orchestration funcional",
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/CompositorSBOS/",
    ),
    AgentBuildSpec(
        name="Bibliotecario-SBOS",
        order=2, perfil="staff", subfase="2a",
        language="python", max_iter=3,
        gate_criteria="SKDATA schemas + catalog queries funcionales",
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BibliotecarioSBOS/",
    ),
    AgentBuildSpec(
        name="Orquesta-Core-SBOS",
        order=3, perfil="nativo", subfase="2a",
        language="python", max_iter=5,
        gate_criteria="10/10 módulos PGE APROBADOS 1/1",
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/OrquestaCoreSBOS/",
    ),
    AgentBuildSpec(
        name="Biblioteca-SBOS",
        order=4, perfil="fundacional", subfase="2a",
        language="sql", max_iter=3,
        gate_criteria="DDL validado: FK resueltas, índices correctos, sin cruces",
        components=["bkernel_db (8 tables)", "biedata_db (3)", "bauth_db (4)",
                     "bcompass_db (3)", "bos_db (2)"],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BibliotecaSBOS/",
    ),
    # Sub-fase 2b — Dominio P1
    AgentBuildSpec(
        name="bos-agent",
        order=5, perfil="dominio", subfase="2b",
        language="go", max_iter=5,
        gate_criteria="IAM Installer bootstrap >=3 ejec sin error + Core UI funcional",
        components=["bos.service (Go)", "Core UI (Flutter)"],
        depends_on=[4],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/",
    ),
    AgentBuildSpec(
        name="infra-agent",
        order=6, perfil="dominio", subfase="2b",
        language="yaml", max_iter=5,
        gate_criteria="bootstrap 3 ejec sin error + kube-bench CIS Level 1 100% + restore 7/7 PASS",
        components=["K8s manifests", "Vault config", "Patroni HA", "pgBackRest"],
        depends_on=[5],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/InfraAgent/",
    ),
    AgentBuildSpec(
        name="bkernel-agent",
        order=7, perfil="dominio", subfase="2b",
        language="rust", max_iter=5,
        gate_criteria="3 ciclos PGE APROBADOS con CDC funcional + rule engine O(1)",
        components=["bKernel (Rust)", "biedata (Rust)"],
        depends_on=[4, 6],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/",
    ),
    AgentBuildSpec(
        name="bauth-agent",
        order=8, perfil="dominio", subfase="2b",
        language="go", max_iter=5,
        gate_criteria="sync_status SYNCED 3 RolTemplates + 5 SPIs Java compilados",
        components=["bAuth (Go)", "5 Keycloak SPIs (Java)"],
        depends_on=[6, 7],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/",
    ),
    # Sub-fase 2c — Fundacionales P1 + Dominio P2
    AgentBuildSpec(
        name="Observabilidad-SBOS",
        order=9, perfil="fundacional", subfase="2c",
        language="yaml", max_iter=3,
        gate_criteria="10 dashboards + health checks funcionales",
        components=["LGTM stack", "dashboards", "alerting rules"],
        depends_on=[6],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/ObservabilidadSBOS/",
    ),
    AgentBuildSpec(
        name="bintelligence-agent",
        order=10, perfil="dominio", subfase="2c",
        language="go", max_iter=5,
        gate_criteria="3 rutas bCompass funcionales + bSearch indexación 3 apps",
        components=["bCompass (Go)", "bSearch (Go)"],
        depends_on=[7],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BintelligenceAgent/",
    ),
    AgentBuildSpec(
        name="bnexus-agent",
        order=11, perfil="dominio", subfase="2c",
        language="go", max_iter=5,
        gate_criteria="flujo QR/NFC <50ms + policy_update push + reconexión validada",
        components=["bhnexus (Go)", "banexus (Go)"],
        depends_on=[8, 10],
        workspace="/opt/skull/orquestador/proyectos/desarrollo/sbos/BnexusAgent/",
    ),
]


def get_agent(name: str) -> Optional[AgentBuildSpec]:
    """Retorna la especificación de construcción de un agente por nombre."""
    for a in SBOS_AGENTS:
        if a.name == name:
            return a
    return None


def get_agents_by_subfase(subfase: str) -> list[AgentBuildSpec]:
    """Retorna los agentes en una sub-fase específica."""
    return [a for a in SBOS_AGENTS if a.subfase == subfase]


def get_ci_gates(language: str) -> dict:
    """Retorna los CI gates para un lenguaje específico."""
    return CI_GATES.get(language, {}).copy()


def max_iter_for(artifact_type: str) -> int:
    """Retorna MAX_ITER para un tipo de artefacto."""
    return MAX_ITER_MAP.get(artifact_type, MAX_ITER_DEFAULT)
