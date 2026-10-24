#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
platform="${1:-sky130hd}"
image="${ORFS_IMAGE:-openroad/orfs:v3.0-3197-g7fcc1909}"
num_cores="${NUM_CORES:-1}"

case "$platform" in
    sky130hd|nangate45|asap7) ;;
    *)
        echo "Usage: $0 [sky130hd|nangate45|asap7]" >&2
        exit 2
        ;;
esac

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to run the OpenROAD Flow Scripts image." >&2
    exit 1
fi

mkdir -p "$script_dir/build"
if ! docker run --rm \
    --user "$(id -u):$(id -g)" \
    --volume "$repo_root:/workspace" \
    --env "NUM_CORES=$num_cores" \
    --workdir /OpenROAD-flow-scripts/flow \
    --entrypoint /bin/bash \
    "$image" \
    -lc "source ../env.sh && make DESIGN_CONFIG=/workspace/r2g/config.mk PLATFORM=$platform WORK_HOME=/workspace/r2g/build NUM_CORES=$num_cores" \
    >"$script_dir/build/openroad.log" 2>&1; then
    tail -n 80 "$script_dir/build/openroad.log" >&2
    exit 1
fi

gds="$script_dir/build/results/$platform/puf_r2g_top/base/6_final.gds"
if [[ ! -s "$gds" ]]; then
    echo "OpenROAD flow completed without producing the expected GDS: $gds" >&2
    exit 1
fi

printf 'GDS generated: %s\n' "$gds"
