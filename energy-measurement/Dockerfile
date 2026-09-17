# syntax=docker/dockerfile:1

# Install with network at build time so every measured stage runs offline.
FROM ubuntu:22.04

ARG PL_SHA=21ac84116633b8c629da03c41e6d6ec2cfb15241
ARG TORCH_VERSION=2.6
ARG UV_VERSION=0.12.9

ENV DEBIAN_FRONTEND=noninteractive

# ubuntu-22.04 system interpreter, Python 3.10.12, as resolved by the reference job.
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -qq -y --no-install-recommends \
        build-essential ca-certificates curl git python3.10 python3.10-dev \
        python3.10-venv python3-pip unzip wget; \
    rm -rf /var/lib/apt/lists/*; \
    python3 -m pip install --no-cache-dir "uv==${UV_VERSION}"

WORKDIR /project

# actions/checkout of the anchored commit, without its history.
RUN set -eux; \
    git init -q .; \
    git remote add origin https://github.com/Lightning-AI/pytorch-lightning.git; \
    git fetch --depth 1 -q origin "$PL_SHA"; \
    git checkout -q --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$PL_SHA"

RUN uv venv /venv --python /usr/bin/python3.10
ENV VIRTUAL_ENV=/venv \
    PATH="/venv/bin:${PATH}"

# ci-tests-pytorch.yml:70-78 and the GITHUB_ENV additions at :96, :127 and :129.
ENV PACKAGE_NAME=lightning \
    TORCH_URL=https://download.pytorch.org/whl/cpu/ \
    FREEZE_REQUIREMENTS=false \
    DISABLE_MPS=0 \
    UV_TORCH_BACKEND=cpu \
    GLOO_SOCKET_IFNAME=eth0 \
    COVERAGE_SCOPE=lightning \
    EXTRA_PREFIX=pytorch-

# Step "Basic setup", :91-92.
RUN uv pip install -q -r .actions/requirements.txt

# Step "Adjust PyTorch versions in requirements files", :114-122.
RUN set -eux; \
    uv pip install -q -r requirements/ci.txt; \
    python -m wget https://raw.githubusercontent.com/Lightning-AI/utilities/main/scripts/adjust-torch-versions.py; \
    for fpath in `ls requirements/**/*.txt`; do \
        python ./adjust-torch-versions.py $fpath ${TORCH_VERSION}; \
    done; \
    cat requirements/pytorch/base.txt

# Versions the reference run 33823300459 resolved, so the image does not drift from it.
RUN cat > /constraints.txt <<'EOC'
absl-py==2.5.0
aiohappyeyeballs==2.7.1
aiohttp==3.14.3
aiosignal==1.4.0
annotated-doc==0.0.5
annotated-types==0.8.0
antlr4-python3-runtime==4.9.3
anyio==4.14.2
async-timeout==5.0.1
attrs==26.1.0
awscli==1.44.87
backports-tarfile==1.2.0
bitsandbytes==0.50.2
botocore==1.42.97
certifi==2026.7.22
cffi==2.1.1
charset-normalizer==3.5.1
click==8.5.0
cloudpickle==3.1.2
colorama==0.4.6
coloredlogs==15.0.1
contourpy==1.3.2
coverage==7.13.5
cryptography==50.0.1
cycler==0.12.1
deepspeed==0.16.9
docstring-parser==0.18.0
docutils==0.19
einops==0.8.2
exceptiongroup==1.3.1
fastapi==0.141.1
filelock==3.32.5
flatbuffers==25.12.19
fonttools==4.64.0
frozenlist==1.8.0
fsspec==2026.7.0
grpcio==1.83.1
h11==0.16.0
hf-xet==1.6.0
hjson==3.1.0
httpcore==1.0.9
httpx==0.28.1
huggingface-hub==1.29.0
humanfriendly==10.0
hydra-core==1.3.6
id==1.6.1
idna==3.19
importlib-metadata==9.0.1
iniconfig==2.3.0
jaraco-classes==3.4.0
jaraco-context==6.1.2
jaraco-functools==4.6.0
jeepney==0.9.0
jinja2==3.1.6
jmespath==1.1.0
joblib==1.6.0
jsonargparse==4.52.0
jsonnet==0.22.0
keyring==25.7.0
kiwisolver==1.5.1
lightning==2.6.2
lightning-utilities==0.15.3
markdown==3.10.3
markdown-it-py==4.2.0
markupsafe==3.0.3
matplotlib==3.10.9
mdurl==0.1.2
ml-dtypes==0.5.4
more-itertools==11.1.0
mpmath==1.3.0
msgpack==1.2.2
multidict==6.7.1
networkx==3.4.2
nh3==0.3.7
ninja==1.13.2
numpy==1.26.4
omegaconf==2.3.1
onnx==1.21.0
onnx-ir==1.0.0
onnxruntime==1.23.2
onnxscript==0.6.2
packaging==26.3
pandas==2.3.3
pillow==12.3.0
pkginfo==1.12.1.2
pluggy==1.6.0
propcache==0.5.2
protobuf==7.36.1
psutil==7.2.2
py-cpuinfo==9.0.0
pyasn1==0.6.4
pycparser==3.0
pydantic==2.13.5
pydantic-core==2.46.5
pygments==2.21.0
pyparsing==3.3.2
pytest==9.0.2
pytest-cov==7.0.0
pytest-random-order==1.2.0
pytest-rerunfailures==16.1
pytest-timeout==2.4.0
python-dateutil==2.9.0.post0
pytz==2026.3.post1
pyyaml==6.0.3
readme-renderer==43.0
requests==2.34.2
requests-toolbelt==1.0.0
rfc3986==2.0.0
rich==14.3.4
rsa==4.7.2
s3transfer==0.16.1
scikit-learn==1.7.2
scipy==1.15.3
secretstorage==3.5.0
setuptools==80.10.2
six==1.17.0
starlette==1.6.0
sympy==1.13.1
tensorboard==2.20.0
tensorboard-data-server==0.7.2
tensorboardx==2.6.5
threadpoolctl==3.6.0
tomli==2.4.1
tomlkit==0.15.1
torch==2.6.0+cpu
torchmetrics==1.9.0
tqdm==4.70.0
twine==6.2.0
typeshed-client==2.13.0
typing-extensions==4.16.0
typing-inspection==0.4.4
tzdata==2026.3
urllib3==2.7.0
uvicorn==0.52.4
werkzeug==3.1.8
wget==3.2
wheel==0.46.3
yarl==1.24.5
zipp==4.1.0
EOC

# Applied from this step on: earlier steps pin packaging<26.1, which :134-136 later upgrades.
ENV UV_CONSTRAINT=/constraints.txt

# Step "Install package & dependencies", :131-139.
RUN set -eux; \
    uv pip install ".[${EXTRA_PREFIX}extra,${EXTRA_PREFIX}test,${EXTRA_PREFIX}strategies]" \
        --upgrade \
        --find-links="${TORCH_URL}"; \
    uv pip install "setuptools<80.10.3"; \
    uv pip list

# Step "Drop PL for LAI", :146-148.
RUN uv pip uninstall pytorch-lightning

# The job's Datasets cache (:150-154) and legacy checkpoints (:172-177), fetched here instead of in the stage.
# Resumable downloads: the helpers' urlretrieve restarts from zero when the S3 connection drops.
RUN <<'EOS'
set -eux
mkdir -p Datasets/MNIST/complete tests/legacy
for f in MNIST/processed/training.pt MNIST/processed/test.pt legacy/checkpoints.zip; do
    case "$f" in legacy/*) out="tests/$f" ;; *) out="Datasets/MNIST/complete/${f##*/}" ;; esac
    wget -c -q -t 60 --waitretry=10 --read-timeout=60 --retry-connrefused \
        -O "$out" "https://pl-public-data.s3.amazonaws.com/$f"
done
PYTHONPATH=/project/tests python - <<'PY'
import os
import torch
from tests_pytorch.helpers.datasets import MNIST, TrialMNIST
root = "/project/Datasets"
src = os.path.join(root, "MNIST", "complete")
dst = os.path.join(root, "MNIST", "digits-0-1-2_nb-100")
os.makedirs(dst, exist_ok=True)
for f in ("training.pt", "test.pt"):
    data, targets = torch.load(os.path.join(src, f), weights_only=True)
    data, targets = TrialMNIST._prepare_subset(data, targets, 100, (0, 1, 2))
    torch.save((data, targets), os.path.join(dst, f))
MNIST(root, download=False)
TrialMNIST(root, download=False)
PY
unzip -o tests/legacy/checkpoints.zip -d tests/legacy/
ls -l tests/legacy/checkpoints/
cd tests/legacy
bash generate_checkpoints.sh
ls -l checkpoints/
EOS

# What the measured build resolves with no index: the freeze minus the project itself,
# plus the pytorch-lightning wheel that lightning pulls in before :148 removes it.
RUN set -eux; \
    uv pip install pip; \
    grep -v -e '^lightning==' -e '^torch==' /constraints.txt > /tmp/wheelhouse.txt; \
    python -m pip download --no-deps --dest /wheelhouse -r /tmp/wheelhouse.txt; \
    python -m pip download --no-deps --dest /wheelhouse --index-url "${TORCH_URL}" "torch==2.6.0+cpu"; \
    python -m pip download --no-deps --dest /wheelhouse "pytorch-lightning==2.6.5"; \
    rm -f /tmp/wheelhouse.txt; \
    ls /wheelhouse | wc -l

# Warms the uv cache for the offline resolution once, as setup-uv's enable-cache (:89) does for the job.
RUN set -eux; \
    uv pip install --no-index --find-links /wheelhouse --constraints /constraints.txt \
        ".[${EXTRA_PREFIX}extra,${EXTRA_PREFIX}test,${EXTRA_PREFIX}strategies]" --upgrade --find-links /wheelhouse; \
    uv pip install --no-index --find-links /wheelhouse "setuptools<80.10.3"; \
    uv pip uninstall pytorch-lightning; \
    uv pip list

WORKDIR /project
