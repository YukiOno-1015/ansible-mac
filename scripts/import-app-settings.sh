#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/dotfiles}"
DOTFILES_HOME="${DOTFILES_DIR}/home"

log() {
  printf '%s\n' "$*"
}

copy_file() {
  local source="$1"
  local relative_target="$2"
  local target="${DOTFILES_HOME}/${relative_target}"

  if [[ ! -f "${source}" ]]; then
    return
  fi

  mkdir -p "$(dirname "${target}")"
  cp "${source}" "${target}"
  log "copied: ${source} -> ${target}"
}

copy_dir() {
  local source="$1"
  local relative_target="$2"
  local target="${DOTFILES_HOME}/${relative_target}"

  if [[ ! -d "${source}" ]]; then
    return
  fi

  mkdir -p "$(dirname "${target}")"
  rm -rf "${target}"
  cp -R "${source}" "${target}"
  log "copied: ${source} -> ${target}"
}

if [[ ! -d "${DOTFILES_DIR}" ]]; then
  log "dotfiles directory not found: ${DOTFILES_DIR}"
  log "Run make dotfiles first, or set DOTFILES_DIR=/path/to/dotfiles."
  exit 1
fi

log "==> Importing VS Code settings"
VSCODE_USER_DIR="${HOME}/Library/Application Support/Code/User"
copy_file "${VSCODE_USER_DIR}/settings.json" "Library/Application Support/Code/User/settings.json"
copy_file "${VSCODE_USER_DIR}/keybindings.json" "Library/Application Support/Code/User/keybindings.json"
copy_file "${VSCODE_USER_DIR}/tasks.json" "Library/Application Support/Code/User/tasks.json"
copy_dir "${VSCODE_USER_DIR}/snippets" "Library/Application Support/Code/User/snippets"
copy_dir "${VSCODE_USER_DIR}/prompts" "Library/Application Support/Code/User/prompts"

log "==> Importing Thunderbird safe profile settings"
THUNDERBIRD_DIR="${HOME}/Library/Thunderbird"
copy_file "${THUNDERBIRD_DIR}/profiles.ini" "Library/Thunderbird/profiles.ini"
copy_file "${THUNDERBIRD_DIR}/installs.ini" "Library/Thunderbird/installs.ini"
while IFS= read -r -d '' profile_dir; do
  profile_relative="${profile_dir#"${THUNDERBIRD_DIR}/"}"
  copy_file "${profile_dir}/prefs.js" "Library/Thunderbird/${profile_relative}/prefs.js"
  copy_file "${profile_dir}/handlers.json" "Library/Thunderbird/${profile_relative}/handlers.json"
  copy_file "${profile_dir}/xulstore.json" "Library/Thunderbird/${profile_relative}/xulstore.json"
done < <(find "${THUNDERBIRD_DIR}/Profiles" -maxdepth 1 -type d -name '*.default*' -print0 2>/dev/null)

log "==> Importing FileZilla settings"
copy_dir "${HOME}/.config/filezilla" ".config/filezilla"
copy_file "${HOME}/Library/Preferences/org.filezilla-project.filezilla.plist" \
  "Library/Preferences/org.filezilla-project.filezilla.plist"

log "==> Importing Eclipse/Pleiades lightweight settings"
copy_file "${HOME}/Library/Application Support/setup-pleiades/Preferences" \
  "Library/Application Support/setup-pleiades/Preferences"
find "${HOME}/Library/Preferences" -maxdepth 1 -type f -iname '*eclipse*' -print0 2>/dev/null |
  while IFS= read -r -d '' preference_file; do
    copy_file "${preference_file}" "Library/Preferences/$(basename "${preference_file}")"
  done

log "==> Done"
log "Review ${DOTFILES_HOME} before committing. Secrets such as Thunderbird passwords, cert DBs, mail stores, and VS Code globalStorage are intentionally skipped."
