#!/usr/bin/env bash

if [[ -z "${CLI_OUTPUT_FORMAT:-}" ]]; then
  CLI_OUTPUT_FORMAT="text"
fi

output_is_json() {
  [[ "${CLI_OUTPUT_FORMAT:-text}" == "json" ]]
}

output_json_string() {
  ruby -rjson -e 'print JSON.dump(ARGV[0])' "${1:-}"
}

output_json_array() {
  local items=("$@")

  if [[ "${#items[@]}" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  local joined=""
  local item
  for item in "${items[@]}"; do
    if [[ -n "$joined" ]]; then
      joined+=","
    fi
    joined+="$item"
  done

  printf '[%s]' "$joined"
}
