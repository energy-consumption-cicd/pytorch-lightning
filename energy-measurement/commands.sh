#!/usr/bin/env bash

set -euo pipefail

STAGE="${1:?stage required}"

export PACKAGE_NAME="${PACKAGE_NAME:-lightning}"
export TORCH_URL="${TORCH_URL:-https://download.pytorch.org/whl/cpu/}"
export UV_TORCH_BACKEND="${UV_TORCH_BACKEND:-cpu}"
export EXTRA_PREFIX="${EXTRA_PREFIX:-pytorch-}"
export COVERAGE_SCOPE="${COVERAGE_SCOPE:-lightning}"
export GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-eth0}"
export GITHUB_RUN_ID="${GITHUB_RUN_ID:-0}"

case "$STAGE" in

  setup)
    cd /project
    bash .actions/pull_legacy_checkpoints.sh
    cd tests/legacy
    PYTHONPATH=/project/tests bash generate_checkpoints.sh
    ls -l checkpoints/
    ;;

  build)
    uv pip install ".[${EXTRA_PREFIX}extra,${EXTRA_PREFIX}test,${EXTRA_PREFIX}strategies]" \
        --upgrade \
        --find-links="${TORCH_URL}"
    uv pip install "setuptools<80.10.3"
    uv pip uninstall pytorch-lightning 2>/dev/null || true
    ;;

  test)
    if [ ! -d /project/tests/legacy/checkpoints ] || \
       [ -z "$(ls -A /project/tests/legacy/checkpoints 2>/dev/null)" ]; then
        echo " Checkpoints legados ausentes em /project/tests/legacy/checkpoints/" >&2
        echo "   Execute 'bash /commands.sh setup' antes, ou use run_pipeline.sh" >&2
        exit 1
    fi

    cd /project/tests/tests_pytorch
    python utilities/test_warnings.py

    echo "GITHUB_RUN_ID: ${GITHUB_RUN_ID}"
    set +e
    python -m coverage run --source "${COVERAGE_SCOPE}" \
        -m pytest . -v --timeout=90 --durations=50 \
        --random-order-seed="${GITHUB_RUN_ID}" \
        --junitxml=junit.xml -o junit_family=legacy
    PYTEST_EXIT=$?
    set -e
    if [ "$PYTEST_EXIT" -gt 1 ]; then
        echo "pytest failed with code ${PYTEST_EXIT} (execution error, not test failure)" >&2
        exit "$PYTEST_EXIT"
    fi
    ;;

  train)
    cd /project
    PYTHONPATH=/project/tests python tests/legacy/simple_classif_training.py
    ;;

  *)
    echo "Stage desconhecido: $STAGE" >&2
    exit 1
    ;;

esac
