# Agent Notes

Non-obvious details that can't be discovered by scanning the codebase.

## Two-directory architecture

This repo (`H:/dev-container-template`) only contains the Docker/compose template. All persistent host-side state lives in a separate directory: `H:/devcontainers/`.

- `H:/devcontainers/config/` — git credentials, GitHub CLI auth, Claude Code config (settings, skills, agents, rules, commands), and `claude.json` (onboarding state + OAuth account)
- `H:/devcontainers/cache/` — git bare mirrors, bun/npm download caches (shared across all containers)
- `H:/devcontainers/includes/` — files overlaid into workspaces: `global/` for all projects, `nextjs/`/`electron/` for type-specific
- `H:/devcontainers/scripts/` — `devup.sh`, `devdown.sh`, `entrypoint.sh`

## Claude Code config loading

Claude Code uses two separate config locations:
- `~/.claude/` — settings, credentials, skills, rules, commands (the directory)
- `~/.claude.json` — global state file in the home directory root (NOT inside `.claude/`). Contains `hasCompletedOnboarding`, `theme`, and `oauthAccount`. Without this file, Claude Code shows the onboarding wizard.

Both are copied (not mounted) from `H:/devcontainers/config/` into the container by the entrypoint so Claude Code can write runtime state.

## Container naming

Docker Compose project name = `{repo-short}-{branch-slug}-{HHMMSS}`. Service containers are `{project}-app-1` and `{project}-db-1`.

## Entrypoint execution order

1. Copy git/gh/Claude config from read-only mounts to writable paths
2. Clone repo (using `--reference` from mirror if available)
3. Checkout/create branch
4. Auto-detect project type (`next.config.*` → nextjs, `electron` in package.json → electron)
5. Overlay includes: `global/` first, then type-specific on top
6. Create `.env` and set `DATABASE_URL`
7. Install deps (bun or npm based on lockfile)
8. Prisma generate + migrate (if `prisma/` exists)

## Git auth

Uses a fine-grained PAT via git credential-store. The credentials file is mounted read-only then copied to a writable path — the credential-store helper requires write access for lock files.
