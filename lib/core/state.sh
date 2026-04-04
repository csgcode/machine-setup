#!/usr/bin/env bash

state_default_config_path() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml"
}

state_default_state_path() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/machine-setup/state.yaml"
}

state_config_path() {
  printf '%s\n' "${MACHINE_SETUP_CONFIG_PATH:-$(state_default_config_path)}"
}

state_state_path() {
  printf '%s\n' "${MACHINE_SETUP_STATE_PATH:-$(state_default_state_path)}"
}

state_read_yaml_value() {
  local file="$1"
  local key_path="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  FILE_PATH="$file" KEY_PATH="$key_path" ruby -ryaml -e '
    data=YAML.load_file(ENV["FILE_PATH"]) || {}
    keys=ENV["KEY_PATH"].split(".")
    value=keys.reduce(data) do |acc, key|
      break nil unless acc.is_a?(Hash)
      acc[key]
    end

    if value.nil?
      exit 0
    elsif value.is_a?(Array)
      puts value.join("\n")
    else
      puts value
    end
  '
}

state_get_config_value() {
  local key_path="$1"
  local env_override=""

  case "$key_path" in
    chezmoi.repo_url)
      env_override="${CHEZMOI_REPO_URL:-}"
      ;;
  esac

  if [[ -n "$env_override" ]]; then
    printf '%s\n' "$env_override"
    return 0
  fi

  state_read_yaml_value "$(state_config_path)" "$key_path"
}

state_get_selected_profile() {
  state_read_yaml_value "$(state_state_path)" "profile"
}

state_get_package_includes() {
  state_read_yaml_value "$(state_state_path)" "packages.include"
}

state_get_package_excludes() {
  state_read_yaml_value "$(state_state_path)" "packages.exclude"
}

state_get_tag_includes() {
  state_read_yaml_value "$(state_state_path)" "tags.include"
}

state_get_tag_excludes() {
  state_read_yaml_value "$(state_state_path)" "tags.exclude"
}

state_array_contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

state_append_unique() {
  local item="$1"
  shift
  local current=("$@")

  if [[ "${#current[@]}" -gt 0 ]] && state_array_contains "$item" "${current[@]}"; then
    printf '%s\n' "${current[@]}"
    return 0
  fi

  current+=("$item")
  printf '%s\n' "${current[@]}"
}

state_remove_item() {
  local needle="$1"
  shift

  local result=()
  local item
  for item in "$@"; do
    if [[ "$item" != "$needle" ]]; then
      result+=("$item")
    fi
  done

  printf '%s\n' "${result[@]}"
}

state_merge_package_selection() {
  local base_packages=()
  local cli_includes=()
  local cli_excludes=()
  local parsing_base=1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include)
        parsing_base=0
        cli_includes+=("$2")
        shift 2
        ;;
      --exclude)
        parsing_base=0
        cli_excludes+=("$2")
        shift 2
        ;;
      --)
        parsing_base=0
        shift
        ;;
      *)
        if [[ "$parsing_base" -eq 1 ]]; then
          base_packages+=("$1")
          shift
        else
          log_error "Unsupported state merge argument: $1"
          return 1
        fi
        ;;
    esac
  done

  local merged=("${base_packages[@]}")
  local item
  local next=()

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    if [[ "${#merged[@]}" -gt 0 ]]; then
      read_lines_into_array next state_append_unique "$item" "${merged[@]}"
    else
      read_lines_into_array next state_append_unique "$item"
    fi
    if [[ "${#next[@]}" -gt 0 ]]; then
      merged=("${next[@]}")
    else
      merged=()
    fi
  done < <(state_get_package_includes)

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    if [[ "${#merged[@]}" -gt 0 ]]; then
      read_lines_into_array next state_remove_item "$item" "${merged[@]}"
    else
      read_lines_into_array next state_remove_item "$item"
    fi
    if [[ "${#next[@]}" -gt 0 ]]; then
      merged=("${next[@]}")
    else
      merged=()
    fi
  done < <(state_get_package_excludes)

  for item in "${cli_includes[@]}"; do
    if [[ "${#merged[@]}" -gt 0 ]]; then
      read_lines_into_array next state_append_unique "$item" "${merged[@]}"
    else
      read_lines_into_array next state_append_unique "$item"
    fi
    if [[ "${#next[@]}" -gt 0 ]]; then
      merged=("${next[@]}")
    else
      merged=()
    fi
  done

  for item in "${cli_excludes[@]}"; do
    if [[ "${#merged[@]}" -gt 0 ]]; then
      read_lines_into_array next state_remove_item "$item" "${merged[@]}"
    else
      read_lines_into_array next state_remove_item "$item"
    fi
    if [[ "${#next[@]}" -gt 0 ]]; then
      merged=("${next[@]}")
    else
      merged=()
    fi
  done

  if [[ "${#merged[@]}" -gt 0 ]]; then
    printf '%s\n' "${merged[@]}"
  fi
}

state_ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

state_write_machine_state() {
  local profile=""
  local package_includes=()
  local package_excludes=()
  local tag_includes=()
  local tag_excludes=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      --include-package)
        package_includes+=("$2")
        shift 2
        ;;
      --exclude-package)
        package_excludes+=("$2")
        shift 2
        ;;
      --include-tag)
        tag_includes+=("$2")
        shift 2
        ;;
      --exclude-tag)
        tag_excludes+=("$2")
        shift 2
        ;;
      *)
        log_error "Unsupported state write argument: $1"
        return 1
        ;;
    esac
  done

  local path
  path="$(state_state_path)"
  state_ensure_parent_dir "$path"

  STATE_PATH="$path" PROFILE_VALUE="$profile" \
  PACKAGE_INCLUDES="$(printf '%s\n' "${package_includes[@]}")" \
  PACKAGE_EXCLUDES="$(printf '%s\n' "${package_excludes[@]}")" \
  TAG_INCLUDES="$(printf '%s\n' "${tag_includes[@]}")" \
  TAG_EXCLUDES="$(printf '%s\n' "${tag_excludes[@]}")" \
  ruby -ryaml -e '
    path=ENV["STATE_PATH"]
    data={
      "profile" => ENV["PROFILE_VALUE"],
      "packages" => {
        "include" => ENV["PACKAGE_INCLUDES"].split("\n").reject(&:empty?),
        "exclude" => ENV["PACKAGE_EXCLUDES"].split("\n").reject(&:empty?)
      },
      "tags" => {
        "include" => ENV["TAG_INCLUDES"].split("\n").reject(&:empty?),
        "exclude" => ENV["TAG_EXCLUDES"].split("\n").reject(&:empty?)
      }
    }
    File.write(path, YAML.dump(data))
  '
}
