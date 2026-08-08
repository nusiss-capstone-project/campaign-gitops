#!/usr/bin/env bash
# Clone an existing campaign env branch (default source: demo) into a new env branch.
#
# Usage:
#   ./scripts/clone-env-branch.sh <new-env> [--from <source-branch>] [--push] [--force]
#
# Examples:
#   ./scripts/clone-env-branch.sh staging
#   ./scripts/clone-env-branch.sh uat --from demo --push
#
# Rewrites namespace / host / Vault / ArgoCD / OTEL / Kafka prefix from source env → new env.
# Does NOT create Vault secrets, DNS, TLS copies, or ArgoCD AppRoot.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/clone-env-branch.sh <new-env> [--from <source-branch>] [--push] [--force]

Examples:
  ./scripts/clone-env-branch.sh staging
  ./scripts/clone-env-branch.sh uat --from demo --push
EOF
  exit 1
}

NEW_ENV=""
FROM_BRANCH="demo"
DO_PUSH=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --from)
      FROM_BRANCH="${2:-}"
      [[ -n "$FROM_BRANCH" ]] || usage
      shift 2
      ;;
    --push) DO_PUSH=1; shift ;;
    --force) FORCE=1; shift ;;
    -*)
      echo "unknown flag: $1" >&2
      usage
      ;;
    *)
      if [[ -z "$NEW_ENV" ]]; then
        NEW_ENV="$1"
        shift
      else
        echo "unexpected arg: $1" >&2
        usage
      fi
      ;;
  esac
done

[[ -n "$NEW_ENV" ]] || usage

if [[ ! "$NEW_ENV" =~ ^[a-z][a-z0-9-]{0,30}$ ]]; then
  echo "env name must be lowercase alphanumeric/hyphen, starting with a letter: got '$NEW_ENV'" >&2
  exit 1
fi

case "$NEW_ENV" in
  dev|main|master|local)
    echo "refusing reserved env name: $NEW_ENV" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree dirty; commit/stash first" >&2
  exit 1
fi

git fetch origin "$FROM_BRANCH" >/dev/null 2>&1 || true

if git show-ref --verify --quiet "refs/heads/$NEW_ENV" || git show-ref --verify --quiet "refs/remotes/origin/$NEW_ENV"; then
  if [[ "$FORCE" -ne 1 ]]; then
    echo "branch '$NEW_ENV' already exists (local or origin). use --force to recreate from $FROM_BRANCH" >&2
    exit 1
  fi
  git checkout "$FROM_BRANCH" >/dev/null 2>&1 || git checkout -B "$FROM_BRANCH" "origin/$FROM_BRANCH"
  git branch -D "$NEW_ENV" >/dev/null 2>&1 || true
fi

# Prefer local source branch (may be ahead of origin, e.g. just added this script).
SRC_REF=""
if git show-ref --verify --quiet "refs/heads/$FROM_BRANCH"; then
  SRC_REF="$FROM_BRANCH"
elif git show-ref --verify --quiet "refs/remotes/origin/$FROM_BRANCH"; then
  SRC_REF="origin/$FROM_BRANCH"
else
  echo "source branch not found: $FROM_BRANCH" >&2
  exit 1
fi

SRC_ENV="$(git show "$SRC_REF:traefik/ingressroute.yaml" 2>/dev/null | sed -n 's/^  namespace: campaign-//p' | head -1)"
if [[ -z "$SRC_ENV" ]]; then
  SRC_ENV="$FROM_BRANCH"
fi

if [[ "$SRC_ENV" == "$NEW_ENV" ]]; then
  echo "source env and new env are the same: $NEW_ENV" >&2
  exit 1
fi

echo "cloning env '$SRC_ENV' ($SRC_REF) → '$NEW_ENV' (branch $NEW_ENV)"

git checkout -B "$NEW_ENV" "$SRC_REF"

rename_if_exists() {
  local from="$1" to="$2"
  if [[ -e "$from" ]]; then
    mkdir -p "$(dirname "$to")"
    git mv "$from" "$to"
  fi
}

rename_if_exists \
  "platform/loongcollector/pipelines/campaign-${SRC_ENV}-stdout.yaml" \
  "platform/loongcollector/pipelines/campaign-${NEW_ENV}-stdout.yaml"

rename_if_exists \
  "argocd/applications/loongcollector-${SRC_ENV}-pipeline.yaml" \
  "argocd/applications/loongcollector-${NEW_ENV}-pipeline.yaml"

# Doc: DEMO.md or <src>.md → <new>.md
# On case-insensitive FS, [[ -f demo.md ]] matches DEMO.md — use git ls-files.
if git ls-files --error-unmatch "${SRC_ENV}.md" >/dev/null 2>&1; then
  git mv "${SRC_ENV}.md" "${NEW_ENV}.md"
elif git ls-files --error-unmatch DEMO.md >/dev/null 2>&1; then
  git mv DEMO.md "${NEW_ENV}.md"
fi

sedi() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Exclude this script from rewrites.
TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT
git ls-files | grep -v '^scripts/clone-env-branch.sh$' >"$TMP_LIST"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  grep -Iq . "$f" 2>/dev/null || continue

  sedi \
    -e "s/campaign-${SRC_ENV}/campaign-${NEW_ENV}/g" \
    -e "s/${SRC_ENV}\\.campaignhub\\.best/${NEW_ENV}.campaignhub.best/g" \
    -e "s|campaign-center/${SRC_ENV}/|campaign-center/${NEW_ENV}/|g" \
    -e "s/campaign-center-${SRC_ENV}/campaign-center-${NEW_ENV}/g" \
    -e "s/x-campaign-otel=${SRC_ENV}/x-campaign-otel=${NEW_ENV}/g" \
    -e "s/deployment\\.environment=${SRC_ENV}/deployment.environment=${NEW_ENV}/g" \
    -e "s/kafkaTopicPrefix: \"${SRC_ENV}\\.\"/kafkaTopicPrefix: \"${NEW_ENV}.\"/g" \
    -e "s/group_id: ${SRC_ENV}-/group_id: ${NEW_ENV}-/g" \
    -e "s/client_id: ${SRC_ENV}-/client_id: ${NEW_ENV}-/g" \
    -e "s/targetRevision: ${SRC_ENV}/targetRevision: ${NEW_ENV}/g" \
    -e "s/name: ${SRC_ENV}-/name: ${NEW_ENV}-/g" \
    -e "s/appEnv: ${SRC_ENV}/appEnv: ${NEW_ENV}/g" \
    -e "s/campaign-${SRC_ENV}-stdout/campaign-${NEW_ENV}-stdout/g" \
    -e "s/loongcollector-${SRC_ENV}-pipeline/loongcollector-${NEW_ENV}-pipeline/g" \
    "$f"
done <"$TMP_LIST"

# Non-dev clones never inject Linkerd (save resources; K8s DNS connectivity unchanged).
if [[ -f charts/go-service/values.yaml ]]; then
  sedi -e 's|linkerd\.io/inject: enabled|linkerd.io/inject: disabled|g' charts/go-service/values.yaml
fi

git add -A
if [[ -n "$(git status --porcelain)" ]]; then
  git commit -m "Clone env ${SRC_ENV} → ${NEW_ENV} via scripts/clone-env-branch.sh"
fi

cat <<EOF

Done. Branch: ${NEW_ENV}
  namespace:     campaign-${NEW_ENV}
  host:          ${NEW_ENV}.campaignhub.best
  vault:         campaign-center/${NEW_ENV}/
  kafka prefix:  ${NEW_ENV}.
  argo apps:     ${NEW_ENV}-*

Next (outside GitOps):
  1. Cloudflare DNS: ${NEW_ENV} (or *) → Traefik EIP, proxied
  2. kubectl: copy acr-secret + campaignhub-origin-tls into campaign-${NEW_ENV}
  3. Vault: campaign-center/${NEW_ENV}/* (+ DBs)
  4. IaC: ArgoCD AppRoot watching branch ${NEW_ENV}
  5. git push -u origin ${NEW_ENV}

EOF

if [[ "$DO_PUSH" -eq 1 ]]; then
  git push -u origin "$NEW_ENV"
  echo "pushed origin/${NEW_ENV}"
fi
