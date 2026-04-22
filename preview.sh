#!/bin/bash
# ---------------------------------------------------------------------------
# preview.sh — run ddev-hosted CI scripts locally
#
# Run from your TYPO3 project root (the directory containing .ddev/).
#
# Usage:
#   preview.sh [deploy|stop|seed]
#
# Auto-detects:
#   - Project name    from .ddev/config.yaml
#   - Git branch      from git rev-parse
#   - SSH key         first of ~/.ssh/id_ed25519, ~/.ssh/id_ecdsa, ~/.ssh/id_rsa
#
# Optional overrides (env vars):
#   PREVIEW_SERVER_HOST   default: deploy.mayfly.live
#   PREVIEW_SERVER_USER   default: deploy
#   PREVIEW_DOMAIN        default: mayfly.live
#   SSH_KEY_FILE          path to private key (overrides auto-detect)
#   DB_FILE               path to .sql or .sql.gz dump (seed only)
# ---------------------------------------------------------------------------

set -euo pipefail

COMMAND=${1:-deploy}
IMAGE="ghcr.io/mikestreety/ddev-hosted:latest"

# ── validate command ─────────────────────────────────────────────────────────
case "$COMMAND" in
  deploy|stop|seed) ;;
  *)
    echo "Usage: $0 [deploy|stop|seed]" >&2
    exit 1
    ;;
esac

# ── server config ────────────────────────────────────────────────────────────
PREVIEW_SERVER_HOST=${PREVIEW_SERVER_HOST:-deploy.mayfly.live}
PREVIEW_SERVER_USER=${PREVIEW_SERVER_USER:-deploy}
PREVIEW_DOMAIN=${PREVIEW_DOMAIN:-mayfly.live}

# ── project name from .ddev/config.yaml ──────────────────────────────────────
if [ ! -f ".ddev/config.yaml" ]; then
  echo "Error: .ddev/config.yaml not found — run from your project root" >&2
  exit 1
fi
CI_PROJECT_NAME=$(grep '^name:' .ddev/config.yaml | awk '{print $2}')
if [ -z "$CI_PROJECT_NAME" ]; then
  echo "Error: could not read 'name:' from .ddev/config.yaml" >&2
  exit 1
fi

# ── git branch ───────────────────────────────────────────────────────────────
CI_COMMIT_REF_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -z "$CI_COMMIT_REF_NAME" ]; then
  echo "Error: could not determine current git branch" >&2
  exit 1
fi

# ── SSH key ──────────────────────────────────────────────────────────────────
SSH_KEY_FILE=${SSH_KEY_FILE:-}
if [ -z "$SSH_KEY_FILE" ]; then
  for candidate in ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa ~/.ssh/id_rsa; do
    if [ -f "$candidate" ]; then
      SSH_KEY_FILE="$candidate"
      break
    fi
  done
fi
if [ -z "$SSH_KEY_FILE" ]; then
  echo "Error: no SSH key found in ~/.ssh/ — set SSH_KEY_FILE to your private key path" >&2
  exit 1
fi

echo "[preview] Command:  ${COMMAND}"
echo "[preview] Project:  ${CI_PROJECT_NAME}"
echo "[preview] Branch:   ${CI_COMMIT_REF_NAME}"
echo "[preview] Server:   ${PREVIEW_SERVER_USER}@${PREVIEW_SERVER_HOST}"
echo "[preview] Domain:   ${PREVIEW_DOMAIN}"
echo "[preview] SSH key:  ${SSH_KEY_FILE}"

# ── DB_FILE for seed ─────────────────────────────────────────────────────────
EXTRA_ARGS=()
if [ "$COMMAND" = "seed" ]; then
  DB_FILE=${DB_FILE:?"DB_FILE is required for seed (path to your .sql or .sql.gz dump)"}
  DB_ABS=$(realpath "$DB_FILE")
  DB_BASENAME=$(basename "$DB_FILE")
  EXTRA_ARGS=(
    -v "${DB_ABS}:/tmp/seed/${DB_BASENAME}"
    -e "DB_FILE=/tmp/seed/${DB_BASENAME}"
  )
fi

docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" \
  -e "SSH_PRIVATE_KEY=$(cat "$SSH_KEY_FILE")" \
  -e "PREVIEW_SERVER_HOST=${PREVIEW_SERVER_HOST}" \
  -e "PREVIEW_SERVER_USER=${PREVIEW_SERVER_USER}" \
  -e "PREVIEW_DOMAIN=${PREVIEW_DOMAIN}" \
  -e "CI_PROJECT_NAME=${CI_PROJECT_NAME}" \
  -e "CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME}" \
  "$IMAGE" \
  "preview-${COMMAND}"
