# =============================================================================
# Dockerfile — AI Coding Agents Workshop ("lite" edition)
#
# Lean workshop image: R 4.6.1 (CRAN) + renv, Python 3 (project-local .venv),
# Node.js 24, Quarto 1.10 (HTML/DOCX), OpenCode 1.18.
#
# Intentionally NOT included: TeX Live (Quarto PDF output is unavailable by
# design), Aider, OpenAI Codex, Gemini CLI, and any preinstalled collection
# of R or Python analysis packages. Students create project-local
# environments instead (see README.md).
#
# Supported platforms: linux/amd64 and linux/arm64 (arm64 build path is
# wired in but UNTESTED on the RC2 build machine — no ARM64/emulation builder
# was available; see README.md).
# Build: docker build -t coding-agent:lite-rc2 .
# Run:   via docker-compose.yml (see README.md)
# =============================================================================

# Base image pinned to the current multiarchitecture OCI index digest of the
# ubuntu:24.04 tag (verified 2026-09-24 via `docker buildx imagetools inspect
# ubuntu:24.04`; the index covers linux/amd64 and linux/arm64). The readable
# tag is kept next to the digest so the base stays identifiable.
FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

# --- Pinned versions ----------------------------------------------------------
# OpenCode is installed from the npm registry at this exact version.
ARG NODE_VERSION=24.21.0
ARG OPENCODE_VERSION=1.18.32
ARG QUARTO_VERSION=1.10.18
ARG RENV_VERSION=1.2.4
# Exact Debian package version of the R packages from the CRAN apt repository
# (verified for amd64 and arm64 in noble-cran40 on 2026-09-24).
ARG R_APT_VERSION=4.6.1-6.2404.0
# Set automatically by BuildKit for the target platform. Every download step
# validates it and fails the build with a clear error when it is empty or
# unsupported (e.g. when building with a legacy builder that sets nothing).
ARG TARGETARCH

# --- OCI image metadata -------------------------------------------------------
LABEL org.opencontainers.image.title="opencode-docker-template (lite)" \
      org.opencontainers.image.description="Workshop image for the AI coding agents course: R 4.6.1 + renv, Python 3, Node.js 24, Quarto 1.10 (no TeX/PDF), OpenCode 1.18. Runs as non-root user 'agent' (UID/GID 1000)." \
      org.opencontainers.image.version="lite-0.1.0-rc2" \
      org.opencontainers.image.authors="Simon Maier" \
      org.opencontainers.image.source="https://github.com/SimonMaier1995/opencode-docker-template" \
      org.opencontainers.image.base.name="docker.io/library/ubuntu:24.04"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# --- 1) Toolchain, R compilation libraries, Python 3 --------------------------
# Minimal set successfully validated in the lite prototype: enough to compile
# and install common R packages and to run project-local Python .venvs.
# R itself comes from the official CRAN repository (next block), NOT from
# Ubuntu (which only ships R 4.3.3 for 24.04).
RUN set -eux; \
    # Retry downloads: Ubuntu mirrors occasionally serve index files that are
    # mid-sync, which would otherwise fail the whole build.
    echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg lsb-release \
      git git-lfs openssh-client \
      build-essential cmake pkg-config procps \
      bzip2 xz-utils zip unzip tar gzip file less nano vim sudo jq \
      libuv1-dev libglpk-dev libgmp-dev \
      zlib1g-dev libbz2-dev liblzma-dev libpcre2-dev libicu-dev \
      libcurl4-openssl-dev libssl-dev libxml2-dev \
      libpng-dev libjpeg-dev libtiff-dev \
      libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
      libreadline-dev libblas-dev liblapack-dev \
      libcairo2-dev libxt-dev libx11-dev \
      libgit2-dev libsqlite3-dev \
      python3 python3-pip python3-venv python-is-python3; \
    \
    # Official CRAN apt repository for Ubuntu 24.04 (noble); provides the
    # current R release for amd64 and arm64 instead of Ubuntu's R 4.3.3.
    # The signing key is installed as a keyring used ONLY by this source
    # (signed-by), not as a globally trusted key.
    install -d -m 0755 /etc/apt/keyrings; \
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
      | gpg --dearmor -o /etc/apt/keyrings/cran-ubuntu-keyring.gpg; \
    chmod 0644 /etc/apt/keyrings/cran-ubuntu-keyring.gpg; \
    # Verify the keyring carries exactly the fingerprints published on CRAN's
    # official instructions page (https://cloud.r-project.org/bin/linux/ubuntu/):
    #   E298A3A825C0D65DFD57CBB651716619E084DAB9  (Michael Rutter, long-standing)
    #   C50236C08FD243001F19B3612A7BA8EA1CFF3E8F  (added 2023)
    fps="$(gpg --show-keys --with-colons /etc/apt/keyrings/cran-ubuntu-keyring.gpg | cut -d: -f10)"; \
    echo "$fps" | grep -q '^E298A3A825C0D65DFD57CBB651716619E084DAB9$' \
      || { echo 'ERROR: CRAN keyring is missing fingerprint E298...DAB9' >&2; exit 1; }; \
    echo "$fps" | grep -q '^C50236C08FD243001F19B3612A7BA8EA1CFF3E8F$' \
      || { echo 'ERROR: CRAN keyring is missing fingerprint C502...3E8F' >&2; exit 1; }; \
    echo "deb [signed-by=/etc/apt/keyrings/cran-ubuntu-keyring.gpg] https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
      > /etc/apt/sources.list.d/cran.list; \
    apt-get update; \
    # Install exactly the pinned R version from CRAN; apt fails the build if
    # this precise package version is no longer downloadable.
    apt-get install -y --no-install-recommends \
      r-base=${R_APT_VERSION} \
      r-base-core=${R_APT_VERSION} \
      r-base-dev=${R_APT_VERSION} \
      r-recommended=${R_APT_VERSION}; \
    # Hard failure if R is not exactly the pinned version.
    Rscript -e 'v <- getRversion(); if (v != "4.6.1") stop(sprintf("R %s installed, expected exactly 4.6.1 from the CRAN repository", as.character(v))); cat("R version check OK:", as.character(v), "\n")'; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- 2) Node.js (official binary tarball, arch-aware, SHA256-verified) --------
# Checksums from the official Node.js release manifest:
#   https://nodejs.org/dist/v24.21.0/SHASUMS256.txt
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) node_arch=x64; node_sha256=fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6 ;; \
      arm64) node_arch=arm64; node_sha256=6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2 ;; \
      *) echo "ERROR: unsupported or empty TARGETARCH '${TARGETARCH}'; this image supports linux/amd64 and linux/arm64 only" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
      -o /tmp/node.tar.xz; \
    echo "${node_sha256}  /tmp/node.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm -f /tmp/node.tar.xz; \
    node --version; \
    npm --version

# --- 3) Quarto (official deb, arch-aware, SHA256-verified; NO TeX Live) -------
# Checksums from the official Quarto release checksum file:
#   https://github.com/quarto-dev/quarto-cli/releases/download/v1.10.18/quarto-1.10.18-checksums.txt
# PDF output is intentionally unavailable (no TeX); HTML and DOCX work.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) quarto_sha256=4bdf5a17df300003beb2f8f0e4dfe568e2ca0ff91318220c8537d2655015c430 ;; \
      arm64) quarto_sha256=ed3f70f63ee12b290ea1e38da08aa7c74c6843f6bed6df828e1e1652ef6d7d98 ;; \
      *) echo "ERROR: unsupported or empty TARGETARCH '${TARGETARCH}'; this image supports linux/amd64 and linux/arm64 only" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb"; \
    echo "${quarto_sha256}  /tmp/quarto.deb" | sha256sum -c -; \
    dpkg -i /tmp/quarto.deb; \
    rm -f /tmp/quarto.deb; \
    quarto --version

# --- 4) renv — the only R package beyond base + recommended ------------------
# SHA256 taken from the official CRAN artifact itself
# (CRAN publishes no checksum file for source packages):
#   https://cran.r-project.org/src/contrib/renv_1.2.4.tar.gz
# Downloaded from the permanent CRAN Archive once renv 1.2.4 has been
# superseded; while 1.2.4 is still the current release it exists only under
# src/contrib, so that URL is used as a fallback. The hard-coded SHA256 is
# enforced either way, so the installed bytes are identical regardless of
# which URL served the tarball.
RUN set -eux; \
    url="https://cran.r-project.org/src/contrib/Archive/renv/renv_${RENV_VERSION}.tar.gz"; \
    if ! curl -fsSL -o /tmp/renv.tar.gz "${url}"; then \
      echo "NOTE: renv ${RENV_VERSION} is still the current CRAN release (not yet in Archive); falling back to the current-release URL"; \
      url="https://cran.r-project.org/src/contrib/renv_${RENV_VERSION}.tar.gz"; \
      curl -fsSL -o /tmp/renv.tar.gz "${url}"; \
    fi; \
    echo "renv tarball fetched from: ${url}"; \
    echo "e63c637dc785d55848d9dbc6c9599378103803efd47c1f3f1f82057c00575e8c  /tmp/renv.tar.gz" | sha256sum -c -; \
    R CMD INSTALL /tmp/renv.tar.gz; \
    Rscript -e 'v <- packageVersion("renv"); if (v != "1.2.4") stop(sprintf("renv %s installed, expected exactly 1.2.4", as.character(v))); cat("renv version check OK:", as.character(v), "\n")'; \
    rm -f /tmp/renv.tar.gz; \
    rm -rf /tmp/Rtmp* /root/.Rhistory /root/.RData

# --- 5) OpenCode --------------------------------------------------------------
# npm lifecycle scripts are blocked image-wide (global ignore-scripts=true).
# The install command below re-enables script execution for that single
# invocation and passes --allow-scripts=opencode-ai, npm's per-package
# allowlist, so script execution during this install is restricted to the
# opencode-ai package. This is the configuration used and tested here; it is
# not a general security guarantee about npm's script handling.
RUN set -eux; \
    npm config --global set ignore-scripts true; \
    npm install -g --ignore-scripts=false --allow-scripts=opencode-ai "opencode-ai@${OPENCODE_VERSION}"; \
    npm cache clean --force; \
    test "$(opencode --version)" = "${OPENCODE_VERSION}"

# --- 6) Non-root runtime user 'agent' (UID/GID 1000) ---------------------------
# ubuntu:24.04 already ships a user 'ubuntu' with UID/GID 1000. Renaming it
# (instead of useradd) guarantees we never create conflicting IDs.
RUN set -eux; \
    existing="$(getent passwd 1000 | cut -d: -f1 || true)"; \
    if [ -z "${existing}" ]; then \
      useradd -m -u 1000 -s /bin/bash ubuntu; \
      existing=ubuntu; \
    fi; \
    if [ "${existing}" != "ubuntu" ]; then \
      echo "ERROR: UID 1000 is already taken by unexpected user '${existing}'" >&2; \
      exit 1; \
    fi; \
    mkdir -p /home/ubuntu; \
    usermod -l agent -d /home/agent -m ubuntu; \
    groupmod -n agent ubuntu; \
    mkdir -p /home/agent/project; \
    chown -R agent:agent /home/agent; \
    # Passwordless sudo so students can deliberately install extra system
    # packages inside their disposable workshop container when needed.
    echo 'agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent; \
    chmod 0440 /etc/sudoers.d/agent; \
    id agent

# --- Runtime configuration -----------------------------------------------------
ENV HOME=/home/agent
WORKDIR /home/agent/project
USER agent
CMD ["/bin/bash"]
