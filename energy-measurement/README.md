# Energy measurement

No file of the upstream project is modified: this directory and
`.github/workflows/energy-measurement.yml` are the only additions, and
`git diff 2.5.0 --stat` on this branch lists only these five paths.

## What is measured

Three stages from job `pl-cpu` of `.github/workflows/ci-tests-pytorch.yml` at commit
`c45c3c92c059661c20443a0a19399f7442db7f90` (tag `2.5.0`), matrix entry
`{os: ubuntu-20.04, pkg-name: lightning, python-version: 3.10, pytorch-version: 2.1}`:

| stage | command | origin |
|---|---|---|
| `build` | `pip install ".[pytorch-extra,pytorch-test,pytorch-strategies]" -U --prefer-binary -r requirements/_integrations/accelerators.txt`, `pip uninstall -y pytorch-lightning`, `rm -rf src/`, sanity check | steps `Install package & dependencies`, `Drop PL for LAI`, `Prevent using raw source`, `Sanity check` |
| `test` | `rm -rf src/`, `python utilities/test_warnings.py`, `coverage run --source lightning -m pytest <ids> -v --timeout=60 --durations=50 --random-order-seed=$GITHUB_RUN_ID --junitxml=junit.xml -o junit_family=legacy` | steps `Prevent using raw source`, `Testing Warnings`, `Testing PyTorch` |
| `train` | `rm -rf src/`, the same `coverage run ... pytest <ids> ...` invocation | steps `Prevent using raw source`, `Testing PyTorch` |

The job runs the suite as one `pytest .` invocation. Here it is split in two by test id:
`train` is the set of tests whose execution path reaches `Trainer.fit`, selected by id from a
`--collect-only` collection at the tag commit (1359 ids); `test` is the complement
(2121 ids). The job passes no `--junitxml`; it is added here because the conformity
check reads `junit.xml`. The two lists are embedded in `commands.sh`, which verifies their sha256 before
any stage runs. Each stage starts a new container from the image, so `rm -rf src/` is
repeated where the job runs it once.

The environment the job installs in its earlier steps, the `Datasets` cache and the legacy
checkpoints are in the image. The tag pins no versions and the logs of its CI runs expired,
so the image pins the versions `pip` resolves against the index as it stood at the tag commit;
`build` resolves from `/wheelhouse` under those versions, with no index. The stages run with `--memory=12g` and no swap.

## Network

The stages run on a Docker bridge created with `--internal`: the container has an `eth0`
with no external route and no name resolution. The DDP tests need a network interface to
exist; `--network none` provides none. `run_pipeline.sh` creates the network if absent and verifies, once per run
and before the baseline, that no external route exists.

Two tests download MNIST into a fresh temporary directory on every run and fail by design
without network: `helpers/test_datasets.py::test_mnist` and
`helpers/test_datasets.py::test_trial_mnist`. They stay in `test`, whose expected exit is
therefore 1; a run is conform when `junit.xml` lists exactly those two as failed.

## Build

```
docker build -t pytorch-lightning-measurement-2.5.0 -f energy-measurement/Dockerfile energy-measurement
```

## Run

```
gh workflow run energy-measurement.yml -f campaign=validation
gh workflow run energy-measurement.yml -f campaign=full
```

`validation` runs run 0 only; `full` runs a warm-up, runs 1 to 10 and the median.
Results, including `junit.xml` per stage, the network check per run and the swap and
temperature sidecars per stage, are uploaded as a workflow artifact.

One run locally:

```
bash energy-measurement/run_pipeline.sh 1
```
