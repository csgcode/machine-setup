#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${MACHINE_SETUP_REPORT_DIR:-$ROOT_DIR/reports}"
IGNORE_FILE="${COLLECT_IGNORE_FILE:-$ROOT_DIR/manifests/collect-ignore.yaml}"
TS="${COLLECT_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
OUT="$REPORT_DIR/current-state-$TS.md"

source "$ROOT_DIR/lib/manifest.sh"
source "$ROOT_DIR/lib/common/checks.sh"

collect_append_unique() {
  local item="$1"
  shift
  local current=("$@")
  local existing=""

  if [[ "$#" -gt 0 ]]; then
    for existing in "${current[@]}"; do
      if [[ "$existing" == "$item" ]]; then
        printf '%s\n' "${current[@]}"
        return 0
      fi
    done
  fi

  current+=("$item")
  if [[ "${#current[@]}" -gt 0 ]]; then
    printf '%s\n' "${current[@]}"
  fi
}

collect_array_contains() {
  local needle="$1"
  shift
  local item=""

  if [[ "$#" -eq 0 ]]; then
    return 1
  fi

  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

collect_ignore_values() {
  local key_path="$1"

  if [[ ! -f "$IGNORE_FILE" ]]; then
    return 0
  fi

  IGNORE_FILE_PATH="$IGNORE_FILE" IGNORE_KEY_PATH="$key_path" ruby -ryaml -e '
    data=YAML.load_file(ENV["IGNORE_FILE_PATH"]) || {}
    keys=ENV["IGNORE_KEY_PATH"].split(".")
    value=keys.reduce(data) do |acc, key|
      break nil unless acc.is_a?(Hash)
      acc[key]
    end

    exit 0 if value.nil?
    if value.is_a?(Array)
      puts value
    else
      puts value
    end
  '
}

collect_capture_lines() {
  local target_var="$1"
  shift
  local output=""
  local status=0
  local line=""

  eval "$target_var=()"

  output="$("$@" 2>/dev/null)" || status=$?
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      eval "$target_var+=(\"\$line\")"
    done <<< "$output"
  fi

  return "$status"
}

collect_capture_npm_globals() {
  local target_var="$1"
  local lines=()
  local parsed=()
  local line=""
  local package_name=""
  local first_line=1

  collect_capture_lines lines npm list -g --depth=0 --location=global --parseable || true
  for line in "${lines[@]}"; do
    [[ -z "$line" ]] && continue
    if [[ "$first_line" -eq 1 ]]; then
      first_line=0
      continue
    fi
    package_name="$line"
    if [[ "$package_name" == */node_modules/* ]]; then
      package_name="${package_name##*/node_modules/}"
    else
      package_name="$(basename "$package_name")"
      if [[ "$(basename "$(dirname "$line")")" == @* ]]; then
        package_name="$(basename "$(dirname "$line")")/$package_name"
      fi
    fi
    [[ "$package_name" == "lib" ]] && continue
    [[ "$package_name" == "node_modules" ]] && continue
    read_lines_into_array parsed collect_append_unique "$package_name" "${parsed[@]+"${parsed[@]}"}"
  done

  eval "$target_var=()"
  if [[ "${#parsed[@]}" -gt 0 ]]; then
    eval "$target_var=(\"\${parsed[@]}\")"
  fi
}

collect_write_list_section() {
  local title="$1"
  shift
  local items=("$@")
  local item=""

  echo "## $title"
  echo '```'
  if [[ "${#items[@]}" -eq 0 ]]; then
    echo "(none)"
  else
    for item in "${items[@]}"; do
      echo "$item"
    done
  fi
  echo '```'
  echo
}

collect_write_command_section() {
  local title="$1"
  shift

  echo "## $title"
  echo '```'
  "$@" 2>/dev/null || true
  echo '```'
  echo
}

mkdir -p "$REPORT_DIR"

brew_formulae=()
brew_leaves=()
brew_casks=()
brew_services=()
npm_globals=()
ignored_package_ids=()
ignored_formulae=()
ignored_casks=()
ignored_npm=()
ignored_manifest_formulae=()
ignored_manifest_casks=()
manifest_formulae=()
manifest_casks=()
tracked_installed=()
missing_formulae=()
missing_casks=()
missing_npm=()
all_packages=()
pkg=""
kind=""
target=""
check_cmd=""
entry=""
formula=""
cask=""
npm_pkg=""

collect_capture_lines brew_formulae brew list --formula || true
collect_capture_lines brew_leaves brew leaves || true
collect_capture_lines brew_casks brew list --cask || true
collect_capture_lines brew_services brew services list || true
collect_capture_npm_globals npm_globals
collect_capture_lines ignored_package_ids collect_ignore_values ignore.package_ids
collect_capture_lines ignored_formulae collect_ignore_values ignore.brew_formula
collect_capture_lines ignored_casks collect_ignore_values ignore.brew_cask
collect_capture_lines ignored_npm collect_ignore_values ignore.npm_global
read_lines_into_array all_packages list_all_packages

for pkg in "${all_packages[@]}"; do
  [[ -z "$pkg" ]] && continue

  kind="$(package_installer_kind "$pkg" | head -n1)"
  target="$(package_install_target "$pkg" | head -n1)"
  check_cmd="$(package_check_command "$pkg" | head -n1)"

  case "$kind" in
    brew_formula)
      if [[ -n "$target" ]]; then
        if collect_array_contains "$pkg" "${ignored_package_ids[@]+"${ignored_package_ids[@]}"}"; then
          read_lines_into_array ignored_manifest_formulae collect_append_unique "$target" "${ignored_manifest_formulae[@]+"${ignored_manifest_formulae[@]}"}"
        else
          read_lines_into_array manifest_formulae collect_append_unique "$target" "${manifest_formulae[@]+"${manifest_formulae[@]}"}"
        fi
      fi
      if [[ -n "$target" ]] && ! collect_array_contains "$target" "${ignored_formulae[@]+"${ignored_formulae[@]}"}" && ! collect_array_contains "$target" "${ignored_manifest_formulae[@]+"${ignored_manifest_formulae[@]}"}" && collect_array_contains "$target" "${brew_formulae[@]+"${brew_formulae[@]}"}"; then
        tracked_installed+=("$pkg [brew_formula:$target]")
      fi
      ;;
    brew_cask)
      if [[ -n "$target" ]]; then
        if collect_array_contains "$pkg" "${ignored_package_ids[@]+"${ignored_package_ids[@]}"}"; then
          read_lines_into_array ignored_manifest_casks collect_append_unique "$target" "${ignored_manifest_casks[@]+"${ignored_manifest_casks[@]}"}"
        else
          read_lines_into_array manifest_casks collect_append_unique "$target" "${manifest_casks[@]+"${manifest_casks[@]}"}"
        fi
      fi
      if [[ -n "$target" ]] && ! collect_array_contains "$target" "${ignored_casks[@]+"${ignored_casks[@]}"}" && ! collect_array_contains "$target" "${ignored_manifest_casks[@]+"${ignored_manifest_casks[@]}"}" && collect_array_contains "$target" "${brew_casks[@]+"${brew_casks[@]}"}"; then
        tracked_installed+=("$pkg [brew_cask:$target]")
      fi
      ;;
    shell_component)
      if ! collect_array_contains "$pkg" "${ignored_package_ids[@]+"${ignored_package_ids[@]}"}" && [[ -n "$check_cmd" ]] && bash -lc "$check_cmd" >/dev/null 2>&1; then
        tracked_installed+=("$pkg [shell_component:$target]")
      fi
      ;;
  esac
done

for formula in "${brew_leaves[@]+"${brew_leaves[@]}"}"; do
  if collect_array_contains "$formula" "${ignored_formulae[@]+"${ignored_formulae[@]}"}"; then
    continue
  fi
  if collect_array_contains "$formula" "${ignored_manifest_formulae[@]+"${ignored_manifest_formulae[@]}"}"; then
    continue
  fi
  if ! collect_array_contains "$formula" "${manifest_formulae[@]+"${manifest_formulae[@]}"}"; then
    missing_formulae+=("$formula")
  fi
done

for cask in "${brew_casks[@]+"${brew_casks[@]}"}"; do
  if collect_array_contains "$cask" "${ignored_casks[@]+"${ignored_casks[@]}"}"; then
    continue
  fi
  if collect_array_contains "$cask" "${ignored_manifest_casks[@]+"${ignored_manifest_casks[@]}"}"; then
    continue
  fi
  if ! collect_array_contains "$cask" "${manifest_casks[@]+"${manifest_casks[@]}"}"; then
    missing_casks+=("$cask")
  fi
done

for npm_pkg in "${npm_globals[@]+"${npm_globals[@]}"}"; do
  if collect_array_contains "$npm_pkg" "${ignored_npm[@]+"${ignored_npm[@]}"}"; then
    continue
  fi
  missing_npm+=("$npm_pkg")
done

{
  echo "# Machine State Snapshot ($TS)"
  echo
  echo "Ignore file: ${IGNORE_FILE#$ROOT_DIR/}"
  echo
  collect_write_list_section "Manifest-tracked installed packages" "${tracked_installed[@]+"${tracked_installed[@]}"}"
  collect_write_list_section "Installed brew formulae missing from manifest" "${missing_formulae[@]+"${missing_formulae[@]}"}"
  collect_write_list_section "Installed brew casks missing from manifest" "${missing_casks[@]+"${missing_casks[@]}"}"
  collect_write_list_section "Installed npm globals missing from manifest" "${missing_npm[@]+"${missing_npm[@]}"}"
  collect_write_command_section "brew leaves" brew leaves
  collect_write_command_section "brew casks" brew list --cask
  collect_write_command_section "brew services" brew services list
  collect_write_command_section "npm global" npm list -g --depth=0 --location=global
  echo "## zsh plugins from ~/.zshrc"
  echo '```'
  rg -n "plugins=|zsh-autosuggestions|zsh-syntax-highlighting|zsh-z|nvm|fzf" "$HOME/.zshrc" 2>/dev/null || true
  echo '```'
} > "$OUT"

echo "$OUT"
