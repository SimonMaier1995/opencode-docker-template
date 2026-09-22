# =============================================================================
#  Dockerfile — AI Coding Agents Workshop
#  Project files are bind-mounted from the Linux project folder by Compose.
#
#  Sets up: R, Python, opencode, OpenAI Codex, Google Gemini CLI, Aider
#  Build:   docker build -t coding-agent .
#  Run:     docker compose up -d && docker compose exec agent bash
# =============================================================================

# === Base Image: Ubuntu 24.04 LTS ===
FROM ubuntu:24.04

# Avoid interactive prompts during package installation (build-time only)
ARG DEBIAN_FRONTEND=noninteractive

# === 1. System Tools ===
RUN apt-get update && apt-get install -y curl wget git git-lfs build-essential software-properties-common locales sudo nano jq tree zip unzip pandoc libgit2-dev libicu-dev texlive texlive-latex-extra texlive-fonts-recommended texlive-xetex && locale-gen en_US.UTF-8 && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# === 2. R (from CRAN repository for the latest stable version) ===
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common dirmngr && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc && add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" && apt-get update && apt-get install -y --no-install-recommends r-base r-base-dev libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev && rm -rf /var/lib/apt/lists/*

# Install core R packages (this step takes ~10-15 minutes)
RUN Rscript -e "install.packages(c('tidyverse', 'data.table', 'arrow', 'duckdb', 'DBI', 'openxlsx', 'janitor', 'fixest', 'modelsummary', 'haven', 'labelled', 'sandwich', 'lmtest', 'ivreg', 'plm', 'estimatr', 'clubSandwich', 'rdrobust', 'rddensity', 'did', 'did2s', 'DRDID', 'HonestDiD', 'MatchIt', 'WeightIt', 'cobalt', 'binsreg', 'marginaleffects', 'patchwork', 'scales', 'gt', 'kableExtra', 'rmarkdown', 'knitr', 'bookdown', 'renv', 'pak', 'devtools', 'testthat', 'targets', 'here'), repos='https://cloud.r-project.org', Ncpus=4)"

# === 3. Python ===
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir numpy pandas matplotlib scipy statsmodels linearmodels pyfixest polars pyarrow duckdb openpyxl seaborn plotly jupyterlab

# Python SDKs for AI providers (used by Aider and for building custom agents)
RUN pip install --no-cache-dir openai anthropic google-genai
# Aider: open-source AI coding agent with OpenRouter support
RUN pip install --no-cache-dir aider-chat
# Utilities for building custom agents
RUN pip install --no-cache-dir rich prompt_toolkit pydantic

# === 4. Node.js 24 LTS (required for opencode, Codex and Gemini CLI) ===
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list > /dev/null && apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

# === 5. opencode (open-source AI coding agent, used with GLM by Z.ai) ===
RUN npm install -g opencode-ai@latest
# === 6. OpenAI Codex ===
RUN npm install -g @openai/codex
# === 7. Google Gemini CLI ===
RUN npm install -g @google/gemini-cli

# === 8. Quarto (reproducible HTML, PDF and Word reports) ===
ARG QUARTO_VERSION=1.10.18
RUN wget -q "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" -O /tmp/quarto.deb \
    && apt-get update \
    && apt-get install -y /tmp/quarto.deb \
    && rm -f /tmp/quarto.deb \
    && rm -rf /var/lib/apt/lists/* \
    && quarto check install

# The project directory is bind-mounted at runtime by docker-compose.yml.
CMD ["bash"]
