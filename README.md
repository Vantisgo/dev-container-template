# Dev Container Template

Spin up pre-configured dev containers with PostgreSQL, Claude Code, and GitHub auth in seconds. Designed for high-throughput workflows (10-20 containers/day) with caching at every layer.

## Features

- **One command** to clone a repo, install deps, set up the database, and drop into a shell
- **PostgreSQL 17** available in every container, `DATABASE_URL` auto-configured in `.env`
- **Claude Code** pre-installed with full config (settings, skills, rules, agents, credentials)
- **CodeRabbit CLI** pre-installed and authenticated
- **Playwright + Chromium + agent-browser** for browser testing and Claude Code's browser skill
- **GitHub private repos** supported via fine-grained PAT (no interactive login)
- **Fast startup** through layered caching: Docker image, git mirrors, bun/npm package cache
- **Project-type includes** — overlay files (CLAUDE.md, skills, rules) into workspaces without committing them to the repo
- **Auto-detection** of project type (Next.js, Electron) for type-specific config
- **Portable** — one config file (`devcontainers/.env`) stores all machine-specific paths

## New Machine Setup

```bash
git clone https://github.com/Vantisgo/dev-container-template
cd dev-container-template
bash setup.sh H:/devcontainers
```

The setup script:
- Creates the entire `devcontainers/` directory structure (config, cache, includes, scripts)
- Writes the `.env` config file with your paths
- Copies the runtime scripts (`devup`, `devdown`, `entrypoint`)
- Prompts for git name, email, and GitHub PAT
- Tells you which auth files to copy manually (Claude Code, CodeRabbit)
- Optionally adds `devcontainers/scripts/` to your Windows PATH

After setup, fill in the remaining auth files and build the base image:

```bash
devup --build-base
```

## Commands

### `devup`

```
devup <owner/repo> [options]

Options:
  -b, --branch NAME    Create or checkout a branch
  -t, --type TYPE      Project type: nextjs, electron (auto-detected if omitted)
  -n, --name NAME      Custom container name (default: auto-generated)
  --no-shell            Start without attaching a shell
  --build-base          Rebuild the base Docker image
```

### `devdown`

```
devdown <container-name>    Stop and remove a specific container
devdown --all               Stop and remove all dev containers
devdown --list              List running dev containers
```

## Attaching to a Running Container

```bash
docker exec -it -u node <project>-app-1 bash -c "cd /workspace && bash"
```

## Directory Layout

```
dev-container-template/                # This repo — clone once per machine
  .devcontainer/
    Dockerfile                         # Base image: Node 22, Bun, gh, Claude Code, Playwright, CodeRabbit
    docker-compose.yml                 # App + PostgreSQL, volume mounts use ${DEVCONTAINERS_ROOT}
    devcontainer.json                  # VS Code attach support
  scripts/                             # Source scripts (copied to devcontainers/ by setup.sh)
  setup.sh                             # Run once on a new machine

devcontainers/                         # Persistent host-side state — created by setup.sh
  .env                                 # Machine-specific paths (DEVCONTAINERS_ROOT, TEMPLATE_ROOT, GIT_BASH)
  config/
    gitconfig                          # Git user + credential helper
    git-credentials                    # Fine-grained PAT
    gh/hosts.yml                       # GitHub CLI auth
    claude/                            # Claude Code config (settings, skills, rules, etc.)
    claude.json                        # Claude Code global state (onboarding, theme, oauth)
    coderabbit/auth.json               # CodeRabbit CLI auth
  cache/
    git-mirrors/                       # Bare repo mirrors for fast --reference clones
    bun-cache/                         # Shared bun download cache
    npm-cache/                         # Shared npm download cache
  includes/
    global/                            # Files overlaid into every workspace
    nextjs/                            # Files overlaid for Next.js projects
    electron/                          # Files overlaid for Electron projects
  scripts/
    devup.sh / devup.cmd               # Spin up a container
    devdown.sh / devdown.cmd           # Tear down a container
    entrypoint.sh                      # Runs inside every container at startup
```

## Auth Files Reference

When setting up on a new machine, you need to copy these from an existing authenticated machine:

| File | Source on authenticated machine | Destination in devcontainers/ |
|---|---|---|
| Claude Code OAuth tokens | `~/.claude/.credentials.json` | `config/claude/.credentials.json` |
| Claude Code global state | `~/.claude.json` (home root, NOT inside `.claude/`) | `config/claude.json` |
| Claude Code settings | `~/.claude/settings.json` | `config/claude/settings.json` |
| Claude Code skills | `~/.claude/skills/*` | `config/claude/skills/` |
| CodeRabbit auth | `~/.coderabbit/auth.json` | `config/coderabbit/auth.json` |
| Git credentials | (created by setup.sh) | `config/git-credentials` |

## Caching

| Layer | Location | Shared across repos |
|---|---|---|
| Docker base image | Local Docker daemon | Yes |
| Git objects | `cache/git-mirrors/` (bare mirrors) | Per-repo |
| Bun packages | `cache/bun-cache/` | Yes |
| npm packages | `cache/npm-cache/` | Yes |
| Claude Code config | `config/claude/` + `config/claude.json` | Yes |
| Git/GitHub auth | `config/gitconfig` + `config/git-credentials` | Yes |
