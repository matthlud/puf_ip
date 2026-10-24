#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
image="${FORMAL_IMAGE:-openroad/orfs:v3.0-3197-g7fcc1909}"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to run the SymbiYosys formal flow." >&2
    exit 1
fi

docker run --rm \
    --user "$(id -u):$(id -g)" \
    --volume "$repo_root:/workspace" \
    --workdir /workspace \
    --entrypoint /bin/bash \
    "$image" \
    -lc "sby -f -d build/formal/puf_controller formal/puf_controller.sby"
