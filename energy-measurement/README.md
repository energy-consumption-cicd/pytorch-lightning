# Energy measurement

No file of the upstream project is modified: this directory and
`.github/workflows/energy-measurement.yml` are the only additions, and
`git diff 21ac8411 --stat` on this branch lists only these five paths.

## What is measured

Three stages from job `pl-cpu` of `.github/workflows/ci-tests-pytorch.yml` at commit
`21ac84116633b8c629da03c41e6d6ec2cfb15241`, matrix entry
`{pkg-name: lightning, python-version: 3.10, pytorch-version: 2.6}`:

| stage | command | origin |
|---|---|---|
| `build` | `uv pip install ".[pytorch-extra,pytorch-test,pytorch-strategies]" --upgrade`, `uv pip install "setuptools<80.10.3"`, `uv pip uninstall pytorch-lightning`, `rm -rf src/`, sanity check | steps `Install package & dependencies`, `Drop PL for LAI`, `Prevent using raw source`, `Sanity check` |
| `test` | `rm -rf src/`, `python utilities/test_warnings.py`, `coverage run --source lightning -m pytest <ids> -v --timeout=90 --durations=50 --random-order-seed=$GITHUB_RUN_ID --junitxml=junit.xml -o junit_family=legacy` | steps `Prevent using raw source`, `Testing Warnings`, `Testing PyTorch` |
| `train` | `rm -rf src/`, the same `coverage run ... pytest <ids> ...` invocation | steps `Prevent using raw source`, `Testing PyTorch` |

The job runs the suite as one `pytest .` invocation. Here it is split in two by test id:
`train` is the set of tests whose execution path reaches `Trainer.fit`, selected by id from a
`--collect-only` collection at the anchored commit (1527 ids); `test` is the complement
(2298 ids). The two lists are embedded in `commands.sh`, which verifies their sha256 before
any stage runs. Each stage starts a new container from the image, so `rm -rf src/` is
repeated where the job runs it once.

The environment the job installs in its earlier steps, the `Datasets` cache and the legacy
checkpoints are in the image. `build` resolves from `/wheelhouse` under the package versions
the reference run resolved, with no index. The stages run with `--memory=12g` and no swap.

## Network

The stages run on a Docker bridge created with `--internal`: the container has an `eth0`
with no external route and no name resolution. The upstream job sets
`GLOO_SOCKET_IFNAME=eth0`, and the DDP tests need that interface to exist; `--network none`
provides none. `run_pipeline.sh` creates the network if absent and verifies, once per run
and before the baseline, that no external route exists.

Two tests download MNIST into a fresh temporary directory on every run and fail by design
without network: `helpers/test_datasets.py::test_mnist` and
`helpers/test_datasets.py::test_trial_mnist`. They stay in `test`, whose expected exit is
therefore 1; a run is conform when `junit.xml` lists exactly those two as failed.

## Build

```
docker build -t pytorch-lightning-medicao -f energy-measurement/Dockerfile energy-measurement
```

## Run

```
gh workflow run energy-measurement.yml -f campaign=validation
gh workflow run energy-measurement.yml -f campaign=full
```

`validation` runs run 0 only; `full` runs a warm-up, runs 1 to 10 and the median.
Results, including `junit.xml` per stage and the network check per run, are uploaded as a
workflow artifact.

One run locally:

```
bash energy-measurement/run_pipeline.sh 1
```
