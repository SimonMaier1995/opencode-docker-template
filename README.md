# opencode-docker-template (lite)

Docker template for the AI coding agents workshop. Copy **the contents of this
folder** (not the `.git` directory — see below) into your project folder on
your Linux/WSL machine and start the container from there.

**Status: release candidate (`lite-0.1.0-rc2`), not yet a final student
release.** The pull workflow is untested until this RC has actually been
published and pulled in a clean environment, and ARM64 is untested until an
ARM64 image has been built and run.

## What is inside the image

| Tool | Version | Notes |
|---|---|---|
| Ubuntu | 24.04 LTS | base image, pinned by digest in the Dockerfile |
| R | 4.6.1 | from the official CRAN apt repository (pinned package versions) |
| renv | 1.2.4 | the only **additional** CRAN package — R's normal base and recommended packages are of course included with R itself |
| Python | 3.12 (Ubuntu) | clean base; you create project-local `.venv` |
| Node.js | 24.21.0 | SHA256-verified official tarball |
| OpenCode | 1.18.32 | `opencode`, run with your Z.ai/GLM key |
| Quarto | 1.10.18 | HTML and DOCX output |

**Deliberately absent** (keep the image small): TeX Live → **Quarto cannot
produce PDFs**, only HTML/DOCX; Aider, OpenAI Codex, Gemini CLI; any
preinstalled R/Python analysis packages. You install what your project needs,
locally in the project folder, with `renv` and Python `.venv`.

## Preflight check (required, once)

The workshop contract is **host user/group UID and GID 1000**. Files created
inside the container are owned by UID 1000, so your host user must match:

```bash
id -u   # must print 1000
id -g   # must print 1000
```

If either prints something else, files created in the container will not
belong to your host user (you would need `sudo` to edit them). This template
is **not** portable to arbitrary host UIDs — it is a deliberate simplification
for the workshop. On a standard WSL/Ubuntu or Multipass setup the first user
is 1000, so this normally just works.

Also create the agent home volume once (it is *external*, Compose will not
create it):

```bash
docker volume create opencode-agent-home
```

### About the old `opencode-shared` volume

The previous workshop volume **`opencode-shared` must remain untouched**. It
belongs to the retired root-based image and its files are owned by `root`, so
it is incompatible with this non-root `agent` image. Do **not** delete or
chown it. Existing users simply authenticate once again in the new
`opencode-agent-home` volume (`opencode` → `/connect`).

*Optional migration note:* if you really need old OpenCode state (e.g.
`auth.json`), migration requires an explicit backup and a manual ownership
conversion (copy the files out as root, then chown them to UID/GID 1000
before placing them in the new volume). This is not automated and has not
been executed or tested here — re-authenticating is the supported path.

## Start the container (choose ONE path)

Both paths use the same versioned image name and the same Dockerfile, and the
same declared tool versions (R 4.6.1, renv 1.2.4, Node 24.21.0, OpenCode
1.18.32, Quarto 1.10.18). They are **not guaranteed to be byte-identical**:

- **A. Pull** gives you the exact artifact that was tested and published.
- **B. Build locally** produces an image from the same Dockerfile and the
  same declared tool versions, but Ubuntu and CRAN apt repositories can
  publish updated lower-level packages over time, so the byte content can
  drift even though the Dockerfile and tool versions are unchanged.
- Once the RC is published, its **image digest** (shown by
  `docker images --digests`) is the only exact identification of the
  published artifact.

There is no `latest` tag; the pinned tag `lite-0.1.0-rc2` identifies this
release candidate.

**A. Pull the ready-made image** (fast, recommended):

```bash
docker compose pull
docker compose up -d
```

**B. Build the image locally** (no registry account needed):

```bash
docker compose build --pull
docker compose up -d --pull never
```

`--pull` on `build` refreshes the pinned base image and apt metadata so the
build uses what is currently published; `--pull never` on `up` makes sure
Docker never tries to fetch the GHCR image and uses your local build.

Then work inside the container:

```bash
docker compose exec agent bash
opencode           # authenticate via /connect with your Z.ai key
exit               # container keeps running
docker compose down # when you are done (project files stay on the host)
```

## The agent home volume

`opencode-agent-home` is mounted at `/home/agent` (external, manual
lifecycle). It stores OpenCode's persistent state and **login credentials**
(`~/.local/share/opencode/auth.json`) and is **shared between all your
project folders**: authenticate once, use it in every project. Do not delete
it unless you want to log in again, and never commit it anywhere — treat it
like a password. Keep project files in the project folder (bind-mounted at
`/home/agent/project`), not in `$HOME`.

## Everyday project workflow (inside the container)

```bash
# Python: project-local virtual environment
python -m venv .venv && source .venv/bin/activate
pip install <packages>            # stays in <project>/.venv

# R: project-local renv
R                                 # then: renv::init() / renv::snapshot()
```

Both live inside the project folder, so they travel with your project and
survive container recreation. The renv package cache is already pointed at
`<project>/.renv-cache` by the Compose service — no project-level
`.Renviron` is needed (and `.Renviron` is git-ignored because it often holds
personal configuration or secrets). `renv.lock` is meant to be committed;
`.venv/`, `.renv-cache/` and `renv/library/` are not (see `.gitignore`).

## Copying this template into a project

Copy the files, never the repository history:

```bash
mkdir ~/myproject && cd ~/myproject
cp -r /path/to/opencode-docker-template/{Dockerfile,docker-compose.yml,README.md,.gitignore,.dockerignore} .
git init    # optional: fresh history for YOUR project
```

Do **not** copy the `.git` directory — it belongs to the template repository
and would make your project a clone of it.

## Permissions note

The image runs as user `agent` (UID/GID 1000, passwordless `sudo` inside the
disposable container) and `/home/agent/project` is your bind-mounted project
folder. Container-created files are therefore owned by host UID 1000 —
exactly the preflight contract above.
