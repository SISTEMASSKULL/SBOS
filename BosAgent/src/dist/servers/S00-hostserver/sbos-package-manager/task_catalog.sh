#!/usr/bin/env bash
# task_catalog.sh — sbos-package-manager
# Multi-backend package manager dispatcher (D2)
set -euo pipefail
FICHA="sbos-package-manager"

echo "__SBOS__STEP_START__ backend-detect"
    echo "=== Backend Detection ==="
    for be in apt pip helm; do
        case "$be" in
            apt)
                if command -v apt-get &>/dev/null; then
                    echo "  apt: AVAILABLE ($(apt-get --version 2>/dev/null | head -1 || echo 'unknown'))"
                else
                    echo "  apt: NOT AVAILABLE"
                fi
                ;;
            pip)
                if command -v pip3 &>/dev/null; then
                    echo "  pip: AVAILABLE ($(pip3 --version 2>/dev/null || echo 'unknown'))"
                else
                    echo "  pip: NOT AVAILABLE"
                fi
                ;;
            helm)
                if command -v helm &>/dev/null; then
                    echo "  helm: AVAILABLE ($(helm version --short 2>/dev/null || echo 'unknown'))"
                else
                    echo "  helm: NOT AVAILABLE"
                fi
                ;;
        esac
    done
echo "__SBOS__STEP_OK__ backend-detect"

echo "__SBOS__STEP_START__ verify-blobs"
    BLIBS="/etc/bos/blibs/servers/hostserver"
    if [ -d "$BLIBS" ]; then
        echo "  blibs root: $BLIBS"
        echo "  fichas count: $(find "$BLIBS" -maxdepth 2 -name 'manifest.yml' 2>/dev/null | wc -l)"
    else
        echo "  WARNING: blibs directory not found — auto-generated fichas will fail"
    fi
echo "__SBOS__STEP_OK__ verify-blobs"

echo "__SBOS__STEP_START__ bosctl-verify"
    if command -v bosctl &>/dev/null; then
        if bosctl install --help 2>/dev/null | grep -q "backend"; then
            echo "  bosctl: package manager support VERIFIED"
        else
            echo "  WARNING: bosctl does not report package manager support"
        fi
    else
        echo "  bosctl not available — package manager CLI will run in degraded mode"
    fi
echo "__SBOS__STEP_OK__ bosctl-verify"
