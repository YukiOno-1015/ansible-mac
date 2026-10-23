#!/usr/bin/env bash
# Mirror docs/ into a cloned GitHub Wiki directory (one-way: docs/ is the source of truth).
#
# Usage: scripts/sync-wiki.sh <wiki-dir>
#   <wiki-dir> is a clone of <repo>.wiki.git. Committing and pushing are left to the caller.
#
# - docs/README.md becomes Home, and every other docs/<name>.md becomes the page <name>.
# - Relative links become Wiki page links (<name>.md -> <name>, ../README.md -> the repository URL).
# - _Sidebar.md and _Footer.md are generated.
# - Generated pages carry MARKER. A marked page that no longer exists in docs/ is removed.
#   Pages without the marker (written by hand) are left alone.
# - Nothing is written to <wiki-dir> when a generated page links to a missing page or to a file path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="${DOCS_DIR:-${SCRIPT_DIR}/../docs}"
REPOSITORY="${GITHUB_REPOSITORY:-YukiOno-1015/ansible-mac}"
REF="${DOCS_REF:-main}"
REPO_URL="https://github.com/${REPOSITORY}"

# Sidebar order. Pages that are not listed here follow in alphabetical order.
PAGE_ORDER="requirements basic-design detailed-design catalog operations testing design-decisions known-issues"

MARKER_ID="mirrored-from-docs"
MARKER="<!-- ${MARKER_ID}: generated from docs/ by scripts/sync-wiki.sh. Edit docs/ in the repository, not this page. -->"

STAGING_DIR=""

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${STAGING_DIR}" ]]; then
    rm -rf "${STAGING_DIR}"
  fi
}

# Wiki page name for a docs file: README.md -> Home, <name>.md -> <name>.
page_name() {
  local name
  name="$(basename "$1" .md)"
  if [[ "${name}" == "README" ]]; then
    name="Home"
  fi
  printf '%s' "${name}"
}

# First level-1 heading of a docs file. Used as the sidebar label.
page_title() {
  local title
  title="$(sed -n '1s/^# //p' "$1")"
  printf '%s' "${title:-$(basename "$1" .md)}"
}

# Rewrite relative links outside fenced code blocks into Wiki links.
rewrite_links() {
  sed -E '/^```/,/^```/!{
    s|\]\(\.\./README\.md\)|](https://github.com/'"${REPOSITORY}/blob/${REF}"'/README.md)|g
    s|\]\(README\.md(#[^)]*)?\)|](Home\1)|g
    s|\]\(([A-Za-z0-9_-]+)\.md(#[^)]*)?\)|](\1\2)|g
  }' "$1"
}

# Print a Markdown file without its fenced code blocks.
strip_fences() {
  awk '/^```/ { in_fence = !in_fence; next } !in_fence' "$1"
}

# Page names (without extension) in sidebar order, excluding Home.
sorted_pages() {
  local name src
  for name in ${PAGE_ORDER}; do
    if [[ -f "${DOCS_DIR}/${name}.md" ]]; then
      printf '%s\n' "${name}"
    fi
  done
  for src in "${DOCS_DIR}"/*.md; do
    name="$(basename "${src}" .md)"
    if [[ "${name}" == "README" ]]; then
      continue
    fi
    case " ${PAGE_ORDER} " in
      *" ${name} "*) ;;
      *) printf '%s\n' "${name}" ;;
    esac
  done
}

generate_pages() {
  local staging="$1"
  local src name
  for src in "${DOCS_DIR}"/*.md; do
    name="$(page_name "${src}")"
    {
      printf '%s\n\n' "${MARKER}"
      rewrite_links "${src}"
    } >"${staging}/${name}.md"
  done
}

build_sidebar() {
  local staging="$1"
  local name
  {
    printf '%s\n\n' "${MARKER}"
    printf '**[ホーム](Home)**\n\n'
    while IFS= read -r name; do
      printf -- '- [%s](%s)\n' "$(page_title "${DOCS_DIR}/${name}.md")" "${name}"
    done < <(sorted_pages)
    printf '\n---\n\n[リポジトリ](%s) / [docs/](%s/tree/%s/docs)\n' "${REPO_URL}" "${REPO_URL}" "${REF}"
  } >"${staging}/_Sidebar.md"
}

build_footer() {
  local staging="$1"
  {
    printf '%s\n\n' "${MARKER}"
    printf 'このページは [docs/](%s/tree/%s/docs) から自動生成されています。' "${REPO_URL}" "${REF}"
    printf 'Wiki 上で編集しても、次回の同期で上書きされます。\n'
  } >"${staging}/_Footer.md"
}

# Fail when a generated page links to a missing page or still has a relative file link.
check_links() {
  local staging="$1"
  local file target page
  local status=0
  for file in "${staging}"/*.md; do
    while IFS= read -r target; do
      case "${target}" in
        http://* | https://* | mailto:* | "#"*) continue ;;
      esac
      page="${target%%#*}"
      case "${page}" in
        *.md | */*)
          log "error: $(basename "${file}"): relative file link remains: ${target}"
          status=1
          continue
          ;;
      esac
      if [[ ! -f "${staging}/${page}.md" ]]; then
        log "error: $(basename "${file}"): link to a missing page: ${target}"
        status=1
      fi
    done < <(strip_fences "${file}" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' || true)
  done
  return "${status}"
}

# Copy the generated pages into the wiki and drop marked pages that no longer exist in docs/.
publish() {
  local staging="$1"
  local wiki_dir="$2"
  local file name
  for file in "${staging}"/*.md; do
    name="$(basename "${file}")"
    cp "${file}" "${wiki_dir}/${name}"
    log "write: ${name}"
  done
  for file in "${wiki_dir}"/*.md; do
    if [[ ! -e "${file}" ]]; then
      continue
    fi
    name="$(basename "${file}")"
    if [[ -e "${staging}/${name}" ]]; then
      continue
    fi
    if grep -qF "${MARKER_ID}" "${file}"; then
      rm -f "${file}"
      log "remove: ${name}"
    fi
  done
}

main() {
  local wiki_dir="${1:-}"
  if [[ -z "${wiki_dir}" ]]; then
    die "usage: $0 <wiki-dir>"
  fi
  if [[ ! -d "${wiki_dir}" ]]; then
    die "wiki directory not found: ${wiki_dir}"
  fi
  if [[ ! -f "${DOCS_DIR}/README.md" ]]; then
    die "docs index not found: ${DOCS_DIR}/README.md"
  fi

  STAGING_DIR="$(mktemp -d)"
  trap cleanup EXIT

  generate_pages "${STAGING_DIR}"
  build_sidebar "${STAGING_DIR}"
  build_footer "${STAGING_DIR}"
  if ! check_links "${STAGING_DIR}"; then
    die "link check failed. Nothing was written to ${wiki_dir}"
  fi
  publish "${STAGING_DIR}" "${wiki_dir}"
  log "done"
}

main "$@"
