#!/usr/bin/env bash
# Installs the zharness CLI from a GitHub release into ~/.local/bin.
#
# Usage: install-zharness.sh [tag]
#   tag defaults to the latest zharness release. Releases are triggered by
#   pushing a "cli/vX.Y.Z" tag, and the release is published under that same
#   tag with the name "zharness X.Y.Z" — the name is what the default lookup
#   below matches on, so the tag prefix stays free to change.
#
# Requires: gh (authenticated against this repo), tar.
set -euo pipefail

REPO="therealtinhtute/mono-harness"
INSTALL_DIR="${ZHARNESS_INSTALL_DIR:-${HOME}/.local/bin}"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh (GitHub CLI) is required and not on PATH" >&2
  exit 1
fi

# A CA bundle variable left pointing at a removed path (e.g. an uninstalled
# package manager) makes gh fail TLS; drop it so the system roots apply.
for var in SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE; do
  if [ -n "${!var:-}" ] && [ ! -e "${!var}" ]; then
    echo "warning: ignoring ${var}=${!var} (path does not exist)" >&2
    unset "$var"
  fi
done

case "$(uname -s)" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *)
    echo "error: unsupported OS $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) arch="amd64" ;;
  arm64 | aarch64) arch="arm64" ;;
  *)
    echo "error: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac

tag="${1:-}"
if [ -z "$tag" ]; then
  rows=$(gh release list --repo "$REPO" --limit 50 --json tagName,name,isDraft,createdAt \
    --jq '[.[] | select(.name | startswith("zharness ")) | [.isDraft, .createdAt, .tagName] | @tsv] | .[]')
  newest_published_tag=""
  newest_published_at=""
  newest_draft_at=""
  while IFS=$'\t' read -r is_draft created_at row_tag; do
    [ -n "$row_tag" ] || continue
    if [ "$is_draft" = "true" ]; then
      if [[ -z "$newest_draft_at" || "$created_at" > "$newest_draft_at" ]]; then
        newest_draft_at="$created_at"
      fi
    elif [[ -z "$newest_published_at" || "$created_at" > "$newest_published_at" ]]; then
      newest_published_at="$created_at"
      newest_published_tag="$row_tag"
    fi
  done <<<"$rows"
  if [ -z "$newest_published_tag" ]; then
    echo "error: no zharness release found on $REPO" >&2
    exit 1
  fi
  if [[ -n "$newest_draft_at" && "$newest_draft_at" > "$newest_published_at" ]]; then
    echo "error: release still publishing — retry or pass an explicit tag" >&2
    exit 1
  fi
  tag="$newest_published_tag"
fi

asset="zharness_${os}_${arch}.tar.gz"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

echo "installing zharness ${tag} (${os}/${arch}) from ${REPO}..."
gh release download "$tag" --repo "$REPO" --pattern "$asset" --dir "$work_dir"

mkdir -p "$INSTALL_DIR"
tar -xzf "${work_dir}/${asset}" -C "$work_dir" zharness
install -m 0755 "${work_dir}/zharness" "${INSTALL_DIR}/zharness"

echo "installed to ${INSTALL_DIR}/zharness"
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *) echo "warning: ${INSTALL_DIR} is not on PATH" >&2 ;;
esac

installed_version="$("${INSTALL_DIR}/zharness" --version)"
echo "$installed_version"

# An older zharness earlier on PATH (e.g. ~/.cargo/bin) would keep answering.
if command -v zharness >/dev/null 2>&1; then
  path_version="$(zharness --version 2>/dev/null || true)"
  if [ "$path_version" != "$installed_version" ]; then
    echo "warning: zharness on PATH is $(command -v zharness) (${path_version:-unknown}), not ${INSTALL_DIR}/zharness (${installed_version}); remove or reorder it" >&2
  fi
fi

# A new binary may ship newer playbooks than the repositories it manages.
"${INSTALL_DIR}/zharness" update --check --all || true
