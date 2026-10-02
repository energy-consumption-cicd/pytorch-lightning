# syntax=docker/dockerfile:1

# Install with network at build time so every measured stage runs offline.
# Base of the cell's ubuntu-20.04 hosted runner, pinned by digest.
FROM ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update -qq; \
    apt-get install -qq -y --no-install-recommends \
        build-essential ca-certificates curl git unzip wget \
        libbz2-1.0 libexpat1 libffi7 libgdbm6 liblzma5 libncursesw6 libreadline8 \
        libsqlite3-0 libssl1.1 libuuid1 zlib1g; \
    rm -rf /var/lib/apt/lists/*

# The job's Datasets cache and legacy checkpoints, fetched here instead of in a stage.
RUN <<'EOS'
set -eux
mkdir -p /opt/assets
cd /opt/assets
for f in MNIST/processed/training.pt MNIST/processed/test.pt legacy/checkpoints.zip; do
    wget -c -q -t 60 --waitretry=10 --read-timeout=60 --retry-connrefused \
        -O "${f##*/}" "https://pl-public-data.s3.amazonaws.com/$f"
done
sha256sum -c - <<'SUMS'
2f36393c2d71ef95251af44a755e40cef9ebdaad4422543dbf56e9d0716eb3d0  training.pt
1efeabc7f8ad1e8295ed03a956ec7aa3777bc2707c06405f9c9ac4312d8f91ee  test.pt
bd10c71ed4545d72d9c03d15c45476855fa8fffad3fb8a5b4700ef4c8c65f342  checkpoints.zip
SUMS
EOS

# actions/setup-python: the linux-20.04-x64 build of the latest 3.10 patch published before the tag commit.
ARG PYTHON_VERSION=3.10.14
ARG PYTHON_RELEASE=3.10.14-8361245787
ARG PYTHON_SHA256=7f69beb5db939e484ab105554707b141c3e70bcdeeca85aae292fc76ff24741b
ARG PIP_VERSION=24.0
RUN set -eux; \
    dest=/opt/hostedtoolcache/Python/${PYTHON_VERSION}/x64; \
    mkdir -p "$dest"; \
    curl -fsSL -o /tmp/python.tar.gz \
        "https://github.com/actions/python-versions/releases/download/${PYTHON_RELEASE}/python-${PYTHON_VERSION}-linux-20.04-x64.tar.gz"; \
    echo "${PYTHON_SHA256}  /tmp/python.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/python.tar.gz -C "$dest"; \
    rm -f /tmp/python.tar.gz "$dest/setup.sh"; \
    ln -s python3.10 "$dest/bin/python"; \
    ln -s /opt/hostedtoolcache/Python/${PYTHON_VERSION} /opt/hostedtoolcache/Python/current; \
    "$dest/bin/python" -m ensurepip; \
    "$dest/bin/python" -m pip install --no-cache-dir --disable-pip-version-check "pip==${PIP_VERSION}"
ENV PATH="/opt/hostedtoolcache/Python/current/x64/bin:${PATH}" \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /project

# actions/checkout of the tag commit, without its history.
ARG PL_SHA=a42484cf8eaa02e45921205bb5dfbae1a0d14cb9
RUN set -eux; \
    git init -q .; \
    git remote add origin https://github.com/Lightning-AI/pytorch-lightning.git; \
    git fetch --depth 1 -q origin "$PL_SHA"; \
    git checkout -q --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "$PL_SHA"

# ci-tests-pytorch.yml:87-95 and the GITHUB_ENV additions at :130-137.
ENV PACKAGE_NAME=lightning \
    TORCH_URL=https://download.pytorch.org/whl/cpu/torch_stable.html \
    FREEZE_REQUIREMENTS=false \
    DISABLE_MPS=0 \
    PYPI_CACHE_DIR=_pip-wheels \
    COVERAGE_SCOPE=lightning \
    EXTRA_PREFIX=pytorch-

ARG TORCH_VERSION=2.0

# The tag pins no versions and the logs of its CI runs expired: these are the versions pip resolved
# against the index as it stood at the tag commit (2024-06-13T19:58:34Z).
RUN cat > /constraints.txt <<'EOC'
absl-py==2.1.0
aiohttp==3.9.5
aiosignal==1.3.1
antlr4-python3-runtime==4.9.3
anyio==4.4.0
async-timeout==4.0.3
attrs==23.2.0
awscli==1.30.7
backports.tarfile==1.2.0
bitsandbytes==0.43.1
botocore==1.32.7
cachetools==5.3.3
certifi==2024.6.2
cffi==1.16.0
charset-normalizer==3.3.2
click==8.1.7
cloudpickle==2.2.1
colorama==0.4.4
coloredlogs==15.0.1
contourpy==1.2.1
coverage==7.3.1
cryptography==42.0.8
cycler==0.12.1
deepspeed==0.9.3
dnspython==2.6.1
docstring_parser==0.16
docutils==0.16
email_validator==2.1.1
exceptiongroup==1.2.1
fastapi-cli==0.0.4
fastapi==0.111.0
filelock==3.15.1
flatbuffers==24.3.25
fonttools==4.53.0
frozenlist==1.4.1
fsspec==2024.6.0
google-auth-oauthlib==1.0.0
google-auth==2.30.0
grpcio==1.64.1
h11==0.14.0
hjson==3.1.0
httpcore==1.0.5
httptools==0.6.1
httpx==0.27.0
humanfriendly==10.0
hydra-core==1.3.2
idna==3.7
importlib_metadata==7.1.0
importlib_resources==6.4.0
iniconfig==2.0.0
jaraco.classes==3.4.0
jaraco.context==5.3.0
jaraco.functools==4.0.1
jeepney==0.8.0
Jinja2==3.1.4
jmespath==1.0.1
joblib==1.4.2
jsonargparse==4.27.7
keyring==25.2.1
kiwisolver==1.4.5
lightning-habana==1.2.0
lightning-utilities==0.11.2
markdown-it-py==3.0.0
Markdown==3.6
MarkupSafe==2.1.5
matplotlib==3.9.0
mdurl==0.1.2
more-itertools==10.3.0
mpmath==1.3.0
multidict==6.0.5
networkx==3.3
nh3==0.2.17
ninja==1.11.1.1
numpy==1.26.4
oauthlib==3.2.2
omegaconf==2.3.0
onnx==1.14.1
onnxruntime==1.16.3
orjson==3.10.4
packaging==24.1
pandas==2.1.4
pillow==10.3.0
pip==24.0
pkginfo==1.11.1
pluggy==1.5.0
protobuf==4.25.3
psutil==5.9.5
py-cpuinfo==9.0.0
pyasn1==0.6.0
pyasn1_modules==0.4.0
pycparser==2.22
pydantic==1.10.16
Pygments==2.18.0
pyparsing==3.1.2
pytest-cov==4.1.0
pytest-random-order==1.1.0
pytest-rerunfailures==12.0
pytest-timeout==2.1.0
pytest==7.4.0
python-dateutil==2.9.0.post0
python-dotenv==1.0.1
python-multipart==0.0.9
pytorch-lightning==2.2.5
pytz==2024.1
PyYAML==6.0.1
readme_renderer==43.0
requests-oauthlib==2.0.0
requests-toolbelt==1.0.0
requests==2.32.3
rfc3986==2.0.0
rich==13.7.1
rsa==4.7.2
s3transfer==0.8.0
scikit-learn==1.3.2
scipy==1.13.1
SecretStorage==3.3.3
setuptools==65.5.0
shellingham==1.5.4
six==1.16.0
sniffio==1.3.1
starlette==0.37.2
sympy==1.12.1
tensorboard-data-server==0.7.2
tensorboard==2.14.1
tensorboardX==2.6.2.2
threadpoolctl==3.5.0
tomli==2.0.1
torch==2.0.0+cpu
torchmetrics==1.4.0.post0
tqdm==4.66.4
twine==4.0.1
typer==0.12.3
typeshed_client==2.5.1
typing_extensions==4.12.2
tzdata==2024.1
ujson==5.10.0
urllib3==2.0.7
uvicorn==0.30.1
uvloop==0.19.0
watchfiles==0.22.0
websockets==12.0
Werkzeug==3.0.3
wget==3.2
wheel==0.43.0
yarl==1.9.4
zipp==3.19.2
EOC
ENV PIP_CONSTRAINT=/constraints.txt

# Step "basic setup", :104-105.
RUN pip install -q -r .actions/requirements.txt

# Step "Adjust PyTorch versions in requirements files", :111-119.
RUN set -eux; \
    pip install -q -r requirements/ci.txt; \
    python -m wget https://raw.githubusercontent.com/Lightning-AI/utilities/main/scripts/adjust-torch-versions.py; \
    for fpath in `ls requirements/**/*.txt`; do \
        python ./adjust-torch-versions.py $fpath ${TORCH_VERSION}; \
    done; \
    cat requirements/pytorch/base.txt

# Step "Install package & dependencies", :139-145.
RUN set -eux; \
    mkdir -p $PYPI_CACHE_DIR; \
    pip install ".[${EXTRA_PREFIX}extra,${EXTRA_PREFIX}test,${EXTRA_PREFIX}strategies]" -U --prefer-binary \
        -r requirements/_integrations/accelerators.txt \
        --find-links="${TORCH_URL}" --find-links="${PYPI_CACHE_DIR}"; \
    pip list

# Step "Drop PL for LAI", :150-152.
RUN pip uninstall -y pytorch-lightning

# The job's Datasets cache (:162-166) and legacy checkpoints (:184-189).
RUN <<'EOS'
set -eux
mkdir -p Datasets/MNIST/complete tests/legacy
cp /opt/assets/training.pt /opt/assets/test.pt Datasets/MNIST/complete/
cp /opt/assets/checkpoints.zip tests/legacy/
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
unzip -o -q tests/legacy/checkpoints.zip -d tests/legacy/
ls tests/legacy/checkpoints/ | wc -l
cd tests/legacy
bash generate_checkpoints.sh
ls -l checkpoints/ | tail -3
pip list --format=freeze
EOS

# What the measured build resolves with no index: the pinned versions, the CPU torch wheel, and wheels of the
# packages published as sdist only, in place of the job's pypi_wheels cache (:121-128).
RUN set -eux; \
    grep -v -e '^torch==' /constraints.txt > /tmp/wheelhouse.txt; \
    python -m pip download --no-deps --dest /wheelhouse -r /tmp/wheelhouse.txt; \
    python -m pip download --no-deps --dest /wheelhouse --find-links "${TORCH_URL}" "torch==2.0.0+cpu"; \
    rm -f /tmp/wheelhouse.txt; \
    for sdist in /wheelhouse/*.tar.gz /wheelhouse/*.zip; do \
        [ -e "$sdist" ] || continue; \
        python -m pip wheel --no-deps --wheel-dir "$PYPI_CACHE_DIR" "$sdist"; \
    done; \
    ls /wheelhouse | wc -l; ls "$PYPI_CACHE_DIR"

# The measured build once, offline, so a missing wheel fails the image and not a run.
RUN set -eux; \
    pip install --no-index ".[${EXTRA_PREFIX}extra,${EXTRA_PREFIX}test,${EXTRA_PREFIX}strategies]" -U --prefer-binary \
        -r requirements/_integrations/accelerators.txt \
        --find-links=/wheelhouse --find-links="${PYPI_CACHE_DIR}"; \
    pip uninstall -y pytorch-lightning; \
    pip list

WORKDIR /project
