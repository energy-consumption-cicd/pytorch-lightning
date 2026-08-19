# Energy measurement instrumentation

## Purpose

This directory is not part of the upstream PyTorch Lightning repository. It was
added to measure the energy consumption of CI/CD pipeline commands on
controlled hardware, using Intel RAPL counters. The measured construct is the
energy of the CI commands on a controlled bench, not the energy of
GitHub-hosted CI in production.

## Non-invasiveness

No original project file is created or modified. The only additions are this
directory and `.github/workflows/energy-measurement.yml`. Verify with:

```bash
git remote add upstream https://github.com/Lightning-AI/pytorch-lightning.git
git fetch upstream
git diff --name-only upstream/master...HEAD
```

## What is measured

Energy is read from the Intel RAPL counters under
`/sys/class/powercap/intel-rapl`, for four domains: package (`pkg`), cores,
uncore (reported as `gpu`, structurally zero on this bench) and DRAM (`ram`).
Counter deltas are overflow-corrected against `max_energy_range_uj`, read from
sysfs at run time rather than hardcoded.

Each run measures a 120 s idle baseline first and derives a per-second rate per
domain. Reported energy per stage is

```
net = max(raw_delta - baseline_rate * wall_time_s, 0)
```

The clamp at zero prevents a negative DRAM figure on light memory workloads;
the unclamped DRAM value is kept as the diagnostic column
`energy_ram_liquid_raw_j`.

`wall_time_s` covers the whole `docker run --rm` lifecycle, including container
setup and teardown, because the RAPL reading window covers the same interval.

Per-stage CPU time is captured inside the container: file descriptor 3
preserves the workload's stderr while `time` writes to `/timing`, so the CPU
time of child processes is attributed to the stage instead of to the host
`docker` client.

## How to run

```bash
docker build -t pytorch-lightning-medicao -f energy-measurement/Dockerfile .
bash energy-measurement/run_pipeline.sh 1
```

The workflow runs the same script on a self-hosted runner, dispatched manually:

```bash
gh workflow run energy-measurement.yml -f campaign=validation   # run 0 only
gh workflow run energy-measurement.yml -f campaign=full         # 10 runs + median
```

## Stages

Each stage runs in its own container, so nothing the build stage writes survives
into the later stages.

| stage | corresponds to | command |
|---|---|---|
| `setup` (not measured) | upstream "Get legacy checkpoints" | downloads and generates the legacy checkpoints once, outside the measured window |
| `build` | upstream "Install package & dependencies" and "Drop PL for LAI" | `uv pip install ".[pytorch-extra,pytorch-test,pytorch-strategies]" --upgrade`, `setuptools<80.10.3`, then uninstall of `pytorch-lightning` |
| `test` | upstream "Testing Warnings" and "Testing PyTorch" | `python utilities/test_warnings.py`, then `coverage run --source lightning -m pytest . -v --timeout=90 --durations=50 --random-order-seed=$GITHUB_RUN_ID` |
| `train` | the standalone legacy training script | `PYTHONPATH=tests python tests/legacy/simple_classif_training.py` |

Reference cell: `ci-tests-pytorch.yml`, job `pl-cpu`, `lightning` /
Python 3.11 / PyTorch 2.2.2 — cell 1 of 15.

## Deviations from the upstream pipeline

- **Dependencies resolved at image build time.** The upstream job adjusts
  dependency versions at run time; the image pins the resolved versions so the
  measurement is reproducible. RAPL has no network domain.
- **`--network none` is absent in this campaign.** This project's measured
  stages ran with the network reachable; hermeticity came from pre-baking, not
  from enforcement. Note that the `build` stage runs
  `uv pip install --upgrade --find-links=<URL>` without `--no-index`, so a
  dependency resolution against the index can occur inside the measured window.
  The stage accounts for a small share of the pipeline; the limitation is
  declared in the project's fidelity note.
- **`GITHUB_RUN_ID` is fixed** rather than taken from the CI context. It seeds
  the test ordering, so the set of tests executed is unchanged.
- **Two DDP tests fail** on this bench, deterministically, as an artefact of the
  measurement environment rather than of the code; the same tests pass on a
  GitHub-hosted runner. The expected exit code for `test` is therefore 1 for
  this project, and it is pre-registered as such.
- **`setup` is excluded from measurement**, because it fetches artefacts over
  the network and is a one-time preparation, not part of the per-run pipeline.
- **No memory limit.** This campaign predates the `--memory` convention adopted
  later; the flag is absent by generation, not by choice.
- **Coverage instrumentation is part of the measured work**, because the
  reference cell runs it.

## Output schema

One CSV per run, one row per stage plus a `total` row:

```
run, stage, energy_pkg_j, energy_cores_j, energy_gpu_j, energy_ram_j,
wall_time_s, user_time_s, sys_time_s, energy_ram_liquid_raw_j
```

The first nine columns are the official schema shared by every project in the
study; `energy_ram_liquid_raw_j` is diagnostic. This project has no
`wall_time_container_s` column: it predates the column's introduction, so the
locus of any I/O stall cannot be decomposed from these CSVs.

## Reproducibility notes

Bench: Intel Core i7-9700 (8 cores, no SMT), 16 GB RAM, Crucial BX500 SATA SSD,
Ubuntu 24.04 LTS, kernel 6.8.0, Docker 29.x.

Container flags: `--rm --privileged`.

The `build` stage is I/O-bound and its `(user+sys)/wall` ratio is around 0.38,
below the sanity-check threshold of 0.5; this is an expected false positive for
a package-installation stage, not a capture regression.
