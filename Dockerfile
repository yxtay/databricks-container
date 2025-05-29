# hadolint global ignore=DL3008
ARG BASE_IMAGE=ubuntu:24.04@sha256:6015f66923d7afbc53558d7ccffd325d43b4e249f41a6e93eef074c9505d2233

FROM ghcr.io/astral-sh/uv:latest@sha256:0178a92d156b6f6dbe60e3b52b33b421021f46d634aa9f81f42b91445bb81cdf AS uv

FROM ${BASE_IMAGE} AS base

ARG DATABRICKS_RUNTIME_VERSION=16.4
ARG JDK_VERSION=17
ARG PYSPARK_VERSION=3.5.2
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

SHELL ["/bin/bash", "-eux", "-o", "pipefail", "-c"]

COPY <<-EOF /etc/apt/apt.conf.d/99-disable-recommends
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
    iptables \
    # misc
    build-essential \
    && \
    rm -rf /var/lib/apt/lists/* && \
    # Add new user forexit cluster library installation
    useradd libraries && \
    usermod -L libraries && \
    # Warning: the created user has root permissions inside the container
    # Warning: you still need to start the ssh process with `sudo service ssh start`
    id -u ubuntu || useradd --shell /bin/bash --groups sudo ubuntu

# install zulu java instead of openjdk due to license issues https://stackoverflow.com/a/61337953
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
    UV_PYTHON_INSTALL_DIR=/opt

# databricks uses root virtualenv to create virtual environments
COPY --from=uv /uv /uvx /bin/
RUN uv python install && \
    uv venv /usr --allow-existing --seed && \
    uv pip install virtualenv && \
    uv pip list

FROM base AS runtime

# jumpstart package versions
RUN --mount=source=requirements.txt,target=requirements.txt \
    uv venv "${VIRTUAL_ENV}" --seed && \
    uv pip install --requirements requirements.txt pyspark=="${PYSPARK_VERSION}" && \
    # pyspark is actually not required because it will be injected in databricks cluster
    # there are a number of vulnerabilities due to outdated jar files in pyspark
    uv pip uninstall pyspark && \
    uv pip list

HEALTHCHECK CMD ["uv", "pip", "list"]
