# hadolint global ignore=DL3008
# kics-scan disable=fd54f200-402c-4333-a5a4-36ef6709af2f,965a08d7-ef86-4f14-8792-4a3b2098937e
# checkov:skip=CKV_DOCKER_3
ARG BASE_IMAGE=public.ecr.aws/ubuntu/ubuntu:24.04@sha256:ef59d9e82939bbce08973bdffb8761b025f75369fb7d2882cdc4938b5a9e992e

FROM ghcr.io/astral-sh/uv:0.9.21@sha256:15f68a476b768083505fe1dbfcc998344d0135f0ca1b8465c4760b323904f05a AS uv

# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS base

ARG DATABRICKS_RUNTIME_VERSION=17.3
ARG JDK_VERSION=17
ARG PYSPARK_VERSION=4.0.0
ARG PYTHON_VERSION=3.12
ARG UV_EXCLUDE_NEWER

ARG DEBIAN_FRONTEND=noninteractive
ARG PIP_NO_CACHE_DIR=0
ARG PYTHONDONTWRITEBYTECODE=1
ARG VIRTUAL_ENV=/databricks/python3

ENV DATABRICKS_RUNTIME_VERSION=${DATABRICKS_RUNTIME_VERSION} \
    MLFLOW_TRACKING_URI=databricks \
    PATH=${VIRTUAL_ENV}/bin:${PATH} \
    PIP_NO_COMPILE=0 \
    PYARROW_IGNORE_TIMEZONE=1 \
    PYSPARK_PYTHON=${VIRTUAL_ENV}/bin/python \
    PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    # Make sure the USER env variable is set. The files exposed
    # by dbfs-fuse will be owned by this user.
    # Within the container, the USER is always root.
    USER=root \
    VIRTUAL_ENV=${VIRTUAL_ENV}

WORKDIR /databricks
SHELL ["/bin/bash", "-eux", "-o", "pipefail", "-c"]

# Add library user for cluster library installation
RUN useradd --create-home libraries && usermod --lock libraries && \
    # Warning: the created user has root permissions inside the container
    # Warning: you still need to start the ssh process with `sudo service ssh start`
    if ! id -u ubuntu; then useradd --create-home --shell /bin/bash --groups sudo ubuntu; fi

RUN cat <<-EOF > /etc/apt/apt.conf.d/99-disable-recommends
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::AutoRemove::RecommendsImportant "false";
APT::AutoRemove::SuggestsImportant "false";
EOF

# https://github.com/databricks/containers/blob/master/ubuntu/minimal/Dockerfile
# https://github.com/databricks/containers/blob/master/ubuntu/python/Dockerfile
# https://github.com/databricks/containers/blob/master/ubuntu/dbfsfuse/Dockerfile
# https://github.com/databricks/containers/blob/master/ubuntu/ssh/Dockerfile
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    # minimal
    bash \
    coreutils \
    iproute2 \
    procps \
    sudo \
    # zulu java
    ca-certificates \
    curl \
    gnupg \
    # dbfsfuse
    fuse \
    # ssh
    openssh-server \
    # table acl
    acl \
    # mlflow
    git \
    && rm -rf /var/lib/apt/lists/*

# https://docs.azul.com/core/install/debian
RUN curl -s https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" | tee /etc/apt/sources.list.d/zulu.list && \
    apt-get update && \
    apt-get install --yes --no-install-recommends "zulu${JDK_VERSION}-jre-headless" && \
    rm -rf /var/lib/apt/lists/* && \
    java -version

ARG UV_NO_CACHE=1
ENV UV_PYTHON=${PYTHON_VERSION} \
    UV_PYTHON_DOWNLOADS=manual \
    UV_PYTHON_INSTALL_DIR=/opt/python

COPY --from=uv /uv /uvx /bin/
RUN uv python install

FROM base AS build

RUN apt-get update && \
    apt-get install --yes --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN uv venv "${VIRTUAL_ENV}" --seed && \
    uv pip install --no-cache-dir --requirements requirements.txt pyspark=="${PYSPARK_VERSION}" && \
    # pyspark is actually not required because it will be injected in databricks cluster
    # there are a number of vulnerabilities due to outdated jar packages in pyspark
    uv pip uninstall pyspark && \
    uv pip list

FROM base AS runtime

COPY --from=build ${VIRTUAL_ENV} ${VIRTUAL_ENV}

HEALTHCHECK CMD ["uv", "pip", "list"]
