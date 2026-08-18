#!/usr/bin/env bash

set -euo pipefail

if [ ! -x /usr/bin/time ]; then
    echo " /usr/bin/time not found. Instale com: sudo apt-get install time" >&2
    exit 1
fi
if ! command -v docker &>/dev/null; then
    echo " Docker not found no PATH." >&2
    exit 1
fi
if ! command -v awk &>/dev/null; then
    echo " awk not found no PATH." >&2
    exit 1
fi

RUN_NUM="${1:?run number required}"

PROJECT_DIR="${GITHUB_WORKSPACE:-$HOME/experimentos/repositorios/training-intensive/pytorch-lightning}"
MEDICAO_DIR="$HOME/experimentos/medicao"
RESULTS_DIR="${MEDICAO_DIR}/resultados/pytorch-lightning/runs"
COMMANDS_SCRIPT="${MEDICAO_DIR}/repositorios/pytorch-lightning/commands.sh"
DOCKER_IMAGE=pytorch-lightning-medicao
# Idle baseline measured before each run; its per-second rate is subtracted
# from every stage so reported energy reflects workload above idle.
BASELINE_DURATION=120
CSV_OUT="${RESULTS_DIR}/run_$(printf '%02d' "$RUN_NUM").csv"
TIME_FILE=$(mktemp /tmp/rapl_time.XXXXXX)

mkdir -p "$RESULTS_DIR"

declare -A RAPL_PATH
declare -A RAPL_MAX

discover_rapl_domains() {
    while IFS= read -r dir; do
        [ -f "${dir}/name" ] || continue
        [ -f "${dir}/energy_uj" ] || continue
        local name max
        name=$(cat "${dir}/name" 2>/dev/null) || continue
        max=$(cat "${dir}/max_energy_range_uj" 2>/dev/null || echo 0)
        case "$name" in
            package-*) RAPL_PATH[pkg]="$dir";   RAPL_MAX[pkg]="$max"   ;;
            core)      RAPL_PATH[cores]="$dir"; RAPL_MAX[cores]="$max" ;;
            uncore)    RAPL_PATH[gpu]="$dir";   RAPL_MAX[gpu]="$max"   ;;
            dram)      RAPL_PATH[ram]="$dir";   RAPL_MAX[ram]="$max"   ;;
        esac
    done < <(find /sys/class/powercap/ -maxdepth 1 -name "intel-rapl*" \
                  -type l 2>/dev/null | sort)

    echo "RAPL domains found:"
    for domain in pkg cores gpu ram; do
        if [ -n "${RAPL_PATH[$domain]:-}" ]; then
            echo "  $domain  ${RAPL_PATH[$domain]} (max: ${RAPL_MAX[$domain]} µJ)"
        else
            echo "  $domain  (not available)"
        fi
    done
}

read_uj() {
    local domain="$1"
    local path="${RAPL_PATH[$domain]:-}"
    if [ -n "$path" ] && [ -f "${path}/energy_uj" ]; then
        cat "${path}/energy_uj" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

read_all_uj() {
    echo "$(read_uj pkg) $(read_uj cores) $(read_uj gpu) $(read_uj ram)"
}

# RAPL counters wrap at max_energy_range_uj; deltas are overflow-corrected.
delta_uj() {
    local start="$1" end="$2" max="$3"
    if [ "$max" -gt 0 ] && [ "$end" -lt "$start" ]; then
        echo $(( max - start + end ))
    else
        echo $(( end - start ))
    fi
}

uj_to_j() {
    awk "BEGIN { printf \"%.6f\", $1 / 1000000 }"
}

setup_once() {
    local ckpt_dir="${PROJECT_DIR}/tests/legacy/checkpoints"
    local ckpt_count
    ckpt_count=$(find "$ckpt_dir" -name "*.ckpt" 2>/dev/null | wc -l)
    if [ "$ckpt_count" -gt 0 ]; then
        echo "Legacy checkpoints already present (${ckpt_count} .ckpt) at ${ckpt_dir}"
        return 0
    fi

    echo "Initial setup: downloading legacy checkpoints (one-time)..."
    docker run --rm --privileged \
        -v "${PROJECT_DIR}":/project \
        -v "${COMMANDS_SCRIPT}":/commands.sh:ro \
        -w /project \
        "$DOCKER_IMAGE" \
        bash /commands.sh setup

    ckpt_count=$(find "$ckpt_dir" -name "*.ckpt" 2>/dev/null | wc -l)
    if [ "$ckpt_count" -eq 0 ]; then
        echo " Setup falhou: nenhum .ckpt encontrado em ${ckpt_dir}" >&2
        exit 1
    fi
    echo " Checkpoints prontos (${ckpt_count} .ckpt)."
}

echo "========================================"
echo " pytorch-lightning - Run ${RUN_NUM}"
echo "========================================"
echo "PROJECT_DIR:      $PROJECT_DIR"
echo "RESULTS_DIR:      $RESULTS_DIR"
echo "DOCKER_IMAGE:     $DOCKER_IMAGE"
echo ""

if ! docker image inspect "$DOCKER_IMAGE" &>/dev/null; then
    echo "Docker image '$DOCKER_IMAGE' not found." >&2
    echo "  Build it first: docker build -t $DOCKER_IMAGE ..." >&2
    exit 1
fi

setup_once

discover_rapl_domains
echo ""

if [ ! -f "$CSV_OUT" ]; then
    echo "run,stage,energy_pkg_j,energy_cores_j,energy_gpu_j,energy_ram_j,wall_time_s,user_time_s,sys_time_s,energy_ram_liquid_raw_j" \
        > "$CSV_OUT"
fi

echo "⏳ Baseline: aguardando ${BASELINE_DURATION}s de repouso..."
read -r bl_pkg_s bl_cores_s bl_gpu_s bl_ram_s <<< "$(read_all_uj)"
sleep "$BASELINE_DURATION"
read -r bl_pkg_e bl_cores_e bl_gpu_e bl_ram_e <<< "$(read_all_uj)"

bl_delta_pkg=$(delta_uj   "$bl_pkg_s"   "$bl_pkg_e"   "${RAPL_MAX[pkg]:-0}")
bl_delta_cores=$(delta_uj "$bl_cores_s" "$bl_cores_e" "${RAPL_MAX[cores]:-0}")
bl_delta_gpu=$(delta_uj   "$bl_gpu_s"   "$bl_gpu_e"   "${RAPL_MAX[gpu]:-0}")
bl_delta_ram=$(delta_uj   "$bl_ram_s"   "$bl_ram_e"   "${RAPL_MAX[ram]:-0}")

bl_rate_pkg=$(awk   "BEGIN { printf \"%.4f\", $bl_delta_pkg   / $BASELINE_DURATION }")
bl_rate_cores=$(awk "BEGIN { printf \"%.4f\", $bl_delta_cores / $BASELINE_DURATION }")
bl_rate_gpu=$(awk   "BEGIN { printf \"%.4f\", $bl_delta_gpu   / $BASELINE_DURATION }")
bl_rate_ram=$(awk   "BEGIN { printf \"%.4f\", $bl_delta_ram   / $BASELINE_DURATION }")

echo "Taxas de baseline (µJ/s):"
echo "  pkg:   $bl_rate_pkg"
echo "  cores: $bl_rate_cores"
echo "  gpu:   $bl_rate_gpu"
echo "  ram:   $bl_rate_ram"
echo ""

total_j_pkg=0; total_j_cores=0; total_j_gpu=0; total_j_ram=0; total_j_ram_raw=0
total_wall=0;  total_user=0;    total_sys=0

j_pkg_build=0;  j_cores_build=0;  j_gpu_build=0;  j_ram_build=0;  wall_build=0
j_pkg_test=0;   j_cores_test=0;   j_gpu_test=0;   j_ram_test=0;   wall_test=0
j_pkg_train=0;  j_cores_train=0;  j_gpu_train=0;  j_ram_train=0;  wall_train=0

measure_stage() {
    local stage="$1"
    echo " Stage: ${stage} (Run ${RUN_NUM})"

    local timing_dir
    timing_dir=$(mktemp -d)

    read -r uj_pkg_s uj_cores_s uj_gpu_s uj_ram_s <<< "$(read_all_uj)"

    /usr/bin/time -f "%e" -o "$TIME_FILE" \
        docker run --rm --privileged \
            -e GITHUB_RUN_ID="$RUN_NUM" \
            -e "STAGE=$stage" \
            -v "${PROJECT_DIR}":/project \
            -v "${COMMANDS_SCRIPT}":/commands.sh:ro \
            -v "${timing_dir}":/timing \
            -w /project \
            "$DOCKER_IMAGE" \
            bash -c 'exec 3>&2; TIMEFORMAT="%R %U %S"; { time bash /commands.sh "$STAGE" 2>&3; } 2>/timing/time.txt'
  # fd3 preserves the workload stderr while `time` captures wall/user/sys
  # inside the container, so child CPU time is attributed to the stage.

    read -r uj_pkg_e uj_cores_e uj_gpu_e uj_ram_e <<< "$(read_all_uj)"

    local wall_time user_time sys_time
    read -r wall_time < "$TIME_FILE"
    if [ -f "${timing_dir}/time.txt" ]; then
        read -r _r user_time sys_time < "${timing_dir}/time.txt"
    else
        user_time="0.000"; sys_time="0.000"
    fi
    rm -rf "$timing_dir"

    local delta_pkg delta_cores delta_gpu delta_ram
    delta_pkg=$(delta_uj   "$uj_pkg_s"   "$uj_pkg_e"   "${RAPL_MAX[pkg]:-0}")
    delta_cores=$(delta_uj "$uj_cores_s" "$uj_cores_e" "${RAPL_MAX[cores]:-0}")
    delta_gpu=$(delta_uj   "$uj_gpu_s"   "$uj_gpu_e"   "${RAPL_MAX[gpu]:-0}")
    delta_ram=$(delta_uj   "$uj_ram_s"   "$uj_ram_e"   "${RAPL_MAX[ram]:-0}")

    local j_pkg j_cores j_gpu j_ram j_ram_raw
    j_pkg=$(awk   "BEGIN { v=($delta_pkg   - $bl_rate_pkg   * $wall_time)/1e6; printf \"%.6f\", (v>0)?v:0 }")
    j_cores=$(awk "BEGIN { v=($delta_cores - $bl_rate_cores * $wall_time)/1e6; printf \"%.6f\", (v>0)?v:0 }")
    j_gpu=$(awk   "BEGIN { v=($delta_gpu   - $bl_rate_gpu   * $wall_time)/1e6; printf \"%.6f\", (v>0)?v:0 }")
    j_ram=$(awk   "BEGIN { v=($delta_ram   - $bl_rate_ram   * $wall_time)/1e6; printf \"%.6f\", (v>0)?v:0 }")
    j_ram_raw=$(awk "BEGIN { printf \"%.6f\", ($delta_ram - $bl_rate_ram * $wall_time)/1e6 }")

    echo "${RUN_NUM},${stage},${j_pkg},${j_cores},${j_gpu},${j_ram},${wall_time},${user_time},${sys_time},${j_ram_raw}" \
        >> "$CSV_OUT"

    echo "  pkg:    ${j_pkg} J"
    echo "  cores:  ${j_cores} J"
    echo "  gpu:    ${j_gpu} J"
    echo "  ram:    ${j_ram} J"
    echo "  wall:   ${wall_time}s  |  user: ${user_time}s  |  sys: ${sys_time}s"
    echo ""

    total_j_pkg=$(awk   "BEGIN { printf \"%.6f\", $total_j_pkg   + $j_pkg }")
    total_j_cores=$(awk "BEGIN { printf \"%.6f\", $total_j_cores + $j_cores }")
    total_j_gpu=$(awk   "BEGIN { printf \"%.6f\", $total_j_gpu   + $j_gpu }")
    total_j_ram=$(awk   "BEGIN { printf \"%.6f\", $total_j_ram   + $j_ram }")
    total_j_ram_raw=$(awk "BEGIN { printf \"%.6f\", $total_j_ram_raw + $j_ram_raw }")
    total_wall=$(awk    "BEGIN { printf \"%.3f\",  $total_wall    + $wall_time }")
    total_user=$(awk    "BEGIN { printf \"%.3f\",  $total_user    + $user_time }")
    total_sys=$(awk     "BEGIN { printf \"%.3f\",  $total_sys     + $sys_time }")

    printf -v "j_pkg_${stage}"   "%.6f" "$j_pkg"
    printf -v "j_cores_${stage}" "%.6f" "$j_cores"
    printf -v "j_gpu_${stage}"   "%.6f" "$j_gpu"
    printf -v "j_ram_${stage}"   "%.6f" "$j_ram"
    printf -v "wall_${stage}"    "%s"   "$wall_time"
}

measure_stage build
measure_stage test
measure_stage train

rm -f "$TIME_FILE"

echo "${RUN_NUM},total,${total_j_pkg},${total_j_cores},${total_j_gpu},${total_j_ram},${total_wall},${total_user},${total_sys},${total_j_ram_raw}" \
    >> "$CSV_OUT"

echo "========================================"
echo " TOTAL Run ${RUN_NUM}"
echo "  pkg:   ${total_j_pkg} J"
echo "  cores: ${total_j_cores} J"
echo "  gpu:   ${total_j_gpu} J"
echo "  ram:   ${total_j_ram} J"
echo "  wall:  ${total_wall}s"
echo "========================================"
echo ""
echo "CSV gerado: $CSV_OUT"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat >> "$GITHUB_STEP_SUMMARY" <<EOF

## Run ${RUN_NUM} - pytorch-lightning

| Etapa | pkg (J) | cores (J) | gpu (J) | ram (J) | wall (s) |
|---|---|---|---|---|---|
| build  | ${j_pkg_build}  | ${j_cores_build}  | ${j_gpu_build}  | ${j_ram_build}  | ${wall_build}  |
| test   | ${j_pkg_test}   | ${j_cores_test}   | ${j_gpu_test}   | ${j_ram_test}   | ${wall_test}   |
| train  | ${j_pkg_train}  | ${j_cores_train}  | ${j_gpu_train}  | ${j_ram_train}  | ${wall_train}  |
| **total** | **${total_j_pkg}** | **${total_j_cores}** | **${total_j_gpu}** | **${total_j_ram}** | **${total_wall}** |
EOF
fi
