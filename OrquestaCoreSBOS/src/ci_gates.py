"""
ci_gates.py — CI Gate validators for SBOS polyglot stack.

Each validator receives a workspace path and returns (passed: bool, issues: list[str]).
The gate is PASS when all stages succeed with zero issues.
"""

import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from sbos_build_config import CI_GATES, get_ci_gates


@dataclass
class GateResult:
    """Resultado de la validación de CI gates para un agente."""

    language: str
    passed: bool
    stages: dict[str, bool] = field(default_factory=dict)
    issues: list[str] = field(default_factory=list)
    coverage: float = 0.0

    @property
    def summary(self) -> str:
        if self.passed:
            return f"CI PASS — {self.language} ({len(self.stages)}/{len(self.stages)} stages)"
        failed = [k for k, v in self.stages.items() if not v]
        return f"CI FAIL — {self.language} ({len(failed)} stages failed: {', '.join(failed)})"


def _run(cmd: str, cwd: str) -> tuple[bool, str]:
    """Ejecuta un comando y retorna (success, output)."""
    try:
        r = subprocess.run(
            cmd, shell=True, cwd=cwd,
            capture_output=True, text=True, timeout=300,
        )
        return r.returncode == 0, (r.stdout + r.stderr)[:2000]
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT (>300s)"
    except Exception as e:
        return False, str(e)


def validate_rust(workspace: str) -> GateResult:
    """Valida CI gates para código Rust."""
    gates = get_ci_gates("rust")
    result = GateResult(language="rust", passed=True)
    src = str(Path(workspace) / "src")

    stages = [
        ("format", "cargo fmt --check"),
        ("lint", "cargo clippy -- -D warnings 2>&1"),
        ("check", "cargo check"),
        ("test", "cargo test"),
        ("audit", "cargo audit"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_go(workspace: str) -> GateResult:
    """Valida CI gates para código Go."""
    gates = get_ci_gates("go")
    result = GateResult(language="go", passed=True)

    stages = [
        ("format", "test -z \"$(gofmt -l .)\""),
        ("lint", "golangci-lint run ./..."),
        ("vet", "go vet ./..."),
        ("test", "go test -race -count=1 ./..."),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_java(workspace: str) -> GateResult:
    """Valida CI gates para código Java (Keycloak SPIs)."""
    result = GateResult(language="java", passed=True)

    stages = [
        ("format", "mvn spotless:check"),
        ("lint", "mvn checkstyle:check"),
        ("test", "mvn test"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_python(workspace: str) -> GateResult:
    """Valida CI gates para código Python."""
    result = GateResult(language="python", passed=True)

    stages = [
        ("format", "ruff format --check src/"),
        ("lint", "ruff check src/"),
        ("typecheck", "mypy src/"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_bash(workspace: str) -> GateResult:
    """Valida CI gates para scripts Bash."""
    result = GateResult(language="bash", passed=True)

    stages = [
        ("lint", "shellcheck src/*.sh"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_dart(workspace: str) -> GateResult:
    """Valida CI gates para código Dart/Flutter."""
    result = GateResult(language="dart", passed=True)

    stages = [
        ("format", "dart format --output=none ."),
        ("analyze", "flutter analyze"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_yaml(workspace: str) -> GateResult:
    """Valida CI gates para archivos YAML (manifests, config)."""
    result = GateResult(language="yaml", passed=True)

    stages = [
        ("lint", "yamllint ."),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


def validate_sql(workspace: str) -> GateResult:
    """Valida CI gates para archivos SQL."""
    result = GateResult(language="sql", passed=True)

    stages = [
        ("lint", "sqlfluff lint src/"),
    ]

    for name, cmd in stages:
        ok, out = _run(cmd, workspace)
        result.stages[name] = ok
        if not ok:
            result.passed = False
            result.issues.append(f"[{name}] {out[:500]}")

    return result


# ═══════════════════════════════════════════════════════════════
# Dispatcher por lenguaje
# ═══════════════════════════════════════════════════════════════

_VALIDATORS = {
    "rust": validate_rust,
    "go": validate_go,
    "java": validate_java,
    "python": validate_python,
    "bash": validate_bash,
    "dart": validate_dart,
    "yaml": validate_yaml,
    "sql": validate_sql,
}


def run_ci_gates(language: str, workspace: str) -> GateResult:
    """
    Ejecuta la validación de CI gates para un agente.

    Args:
        language: Lenguaje del agente (rust, go, java, python, bash, dart, yaml, sql).
        workspace: Ruta absoluta al workspace del agente.

    Returns:
        GateResult con el resultado de la validación.

    Raises:
        ValueError: Si el lenguaje no está soportado.
    """
    validator = _VALIDATORS.get(language)
    if validator is None:
        raise ValueError(
            f"Lenguaje no soportado: '{language}'. "
            f"Válidos: {', '.join(sorted(_VALIDATORS))}"
        )
    return validator(workspace)
