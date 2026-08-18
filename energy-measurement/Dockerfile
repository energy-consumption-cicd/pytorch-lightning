FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ENV PACKAGE_NAME=lightning
ENV TORCH_URL=https://download.pytorch.org/whl/cpu/
ENV TORCH_URL_STABLE=https://download.pytorch.org/whl/cpu/
ENV TORCH_URL_TEST=https://download.pytorch.org/whl/test/cpu/
ENV UV_TORCH_BACKEND=cpu
ENV EXTRA_PREFIX=pytorch-
ENV COVERAGE_SCOPE=lightning
ENV GLOO_SOCKET_IFNAME=eth0
ENV FREEZE_REQUIREMENTS=0

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y \
        python3.11 \
        python3.11-dev \
        python3.11-venv \
        python3-pip \
        git \
        curl \
        wget \
        unzip \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN pip install uv

RUN uv venv /venv --python 3.11
ENV VIRTUAL_ENV=/venv
ENV PATH="/venv/bin:$PATH"

COPY . /project
WORKDIR /project

RUN uv pip install -q -r .actions/requirements.txt

RUN uv pip install -q -r requirements/ci.txt && \
    python -m wget \
        https://raw.githubusercontent.com/Lightning-AI/utilities/main/scripts/adjust-torch-versions.py && \
    find requirements -name "*.txt" | while read fpath; do \
        python ./adjust-torch-versions.py "$fpath" 2.2.2; \
    done

RUN uv pip install ".[pytorch-extra,pytorch-test,pytorch-strategies]" \
        --upgrade \
        --find-links="${TORCH_URL}" && \
    uv pip install "setuptools<80.10.3"

RUN uv pip uninstall pytorch-lightning 2>/dev/null || true

RUN mkdir -p /wheelhouse && \
    uv pip download \
        ".[pytorch-extra,pytorch-test,pytorch-strategies]" \
        --find-links="${TORCH_URL}" \
        -d /wheelhouse/ 2>/dev/null || true && \
    uv pip download "setuptools<80.10.3" -d /wheelhouse/ 2>/dev/null || true

