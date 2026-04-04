repo_root() {
  local helper_dir
  helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$helper_dir/../.." && pwd
}

count_matches() {
  local needle="$1"
  local haystack="$2"
  printf '%s' "$haystack" | awk -v needle="$needle" 'index($0, needle) { count += 1 } END { print count + 0 }'
}
