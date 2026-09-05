#!/usr/bin/env bash
# =============================================================================
# Publish the workshop branch to a standalone repository as a SINGLE squashed
# commit, carrying no git history from this repository.
#
# Why: GitHub controls visibility per REPOSITORY, not per branch. A branch in a
# private repo cannot be made public on its own, and pushing this repo's history
# would let anyone recover `main` with `git log`. So we export a flattened
# snapshot instead.
#
# Usage:
#   scripts/publish-workshop.sh git@github.com:<owner>/<repo>.git
#   scripts/publish-workshop.sh https://github.com/<owner>/<repo>.git
#
#   DRY_RUN=1 scripts/publish-workshop.sh <url>   # build + check, do not push
#
# Create the target repo first (keep it private until the event):
#   gh repo create <owner>/<repo> --private
# =============================================================================
set -euo pipefail

TARGET_REMOTE="${1:-}"
if [[ -z "$TARGET_REMOTE" ]]; then
  echo "usage: $0 <target-repo-git-url>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> Source branch : $BRANCH"
echo "==> Target repo   : $TARGET_REMOTE"
echo "==> Staging dir   : $STAGE"
echo

# ---- 1. export the tracked worktree (tracked files only, no .git) -----------
echo "==> [1/4] Exporting tracked files"
git archive --format=tar HEAD | tar -x -C "$STAGE"

# Things that must never reach the public repo.
EXCLUDE=(
  "INSTRUCTOR.md"          # instructor-only: pre-provisioning + shared credentials
  "scripts/publish-workshop.sh"
  ".azure"                 # deployment records contain subscription identifiers
  ".github"                # local authoring config, not workshop material
)
for path in "${EXCLUDE[@]}"; do
  rm -rf "${STAGE:?}/${path}"
done
# Local build artifacts and decks that may be untracked but could be copied in.
find "$STAGE" -maxdepth 1 \( -name "*.pptx" -o -name "*.pdf" \) -delete 2>/dev/null || true
find "$STAGE" -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$STAGE" -name ".env" -delete 2>/dev/null || true
find "$STAGE/code/agents/ontology_charts" -name "*.png" -delete 2>/dev/null || true

# ---- 2. secrets sweep (hard gate) -------------------------------------------
echo "==> [2/4] Scanning for secrets and private identifiers"
# Azure built-in role definition GUIDs are public constants, not secrets.
ALLOWED_GUIDS='7f951dda-4ed3-4680-a7ca-43fe172d538d|5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
# Matches: any GUID, personal/tenant names, live Azure endpoints, and hard-coded
# credential VALUES (an assignment to a long literal — not `key = os.getenv(...)`).
PATTERN='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|kinfey|lokinfey|azurecomm\.net|azurecontainerapps\.io|AccessKey=|(api[_-]?key|secret|password|connection[_-]?string)["'"'"']?\s*[:=]\s*["'"'"'][A-Za-z0-9+/=_.-]{16,}'

HITS="$(grep -rInE "$PATTERN" "$STAGE" 2>/dev/null | grep -vE "$ALLOWED_GUIDS" || true)"
if [[ -n "$HITS" ]]; then
  echo "ERROR: potential secrets found — refusing to publish:" >&2
  echo "$HITS" | sed "s|$STAGE/||" >&2
  exit 1
fi
echo "    clean."

# ---- 3. build a fresh single-commit repo ------------------------------------
echo "==> [3/4] Building single-commit snapshot"
cd "$STAGE"
git init -q -b main
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-workshop}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-workshop@example.com}" \
    commit -q -m "Enterprise AI Transformation Labs · AI Company

A 3-hour hands-on workshop: Microsoft Fabric IQ ontology concepts, MCP,
Microsoft Agent Framework, and AKS with Entra workload identity."

COMMITS="$(git rev-list --count HEAD)"
FILES="$(git ls-files | wc -l | tr -d ' ')"
echo "    ${COMMITS} commit, ${FILES} files."
[[ "$COMMITS" == "1" ]] || { echo "ERROR: expected exactly 1 commit" >&2; exit 1; }

# ---- 4. push -----------------------------------------------------------------
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo
  echo "DRY_RUN=1 — not pushing. Snapshot left at:"
  echo "  $STAGE"
  trap - EXIT
  exit 0
fi

echo "==> [4/4] Force-pushing snapshot to $TARGET_REMOTE"
git remote add origin "$TARGET_REMOTE"
git push --force origin main

echo
echo "============================================================"
echo "Published. The target repo now has exactly one commit."
echo "Keep it private until the event, then:"
echo "  gh repo edit <owner>/<repo> --visibility public \\"
echo "     --accept-visibility-change-consequences"
echo "============================================================"
