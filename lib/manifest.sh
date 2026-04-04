#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_FILE="$ROOT_DIR/manifests/packages.yaml"
GROUPS_FILE="$ROOT_DIR/manifests/groups.yaml"

# Uses macOS system Ruby Psych parser for YAML so we don't depend on yq/jq.
ruby_manifest() {
  ruby -ryaml -rjson -e "$1" "$2"
}

list_groups() {
  ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data["groups"].keys.sort' "$GROUPS_FILE"
}

list_group_packages() {
  local group="$1"
  ruby_manifest 'data=YAML.load_file(ARGV[0]); arr=data.dig("groups",ENV["GROUP"],"packages") || []; puts arr' "$GROUPS_FILE"
}

list_all_packages() {
  ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data["packages"].map{|p| p["id"]}.sort' "$PACKAGES_FILE"
}

package_exists() {
  local pkg="$1"
  ruby_manifest 'data=YAML.load_file(ARGV[0]); ids=data["packages"].map{|p| p["id"]}; exit(ids.include?(ENV["PKG"]) ? 0 : 1)' "$PACKAGES_FILE"
}

package_field() {
  local pkg="$1"
  local field="$2"
  PKG="$pkg" FIELD="$field" ruby_manifest 'data=YAML.load_file(ARGV[0]); p=data["packages"].find{|x| x["id"]==ENV["PKG"]}; v=p && p[ENV["FIELD"]]; if v.nil? then exit 0 elsif v.is_a?(Array) then puts v.join("\n") else puts v end' "$PACKAGES_FILE"
}

package_dependencies() {
  local pkg="$1"
  PKG="$pkg" ruby_manifest 'data=YAML.load_file(ARGV[0]); p=data["packages"].find{|x| x["id"]==ENV["PKG"]}; arr=(p && p["depends_on"]) || []; puts arr' "$PACKAGES_FILE"
}

package_summary_table() {
  ruby_manifest 'data=YAML.load_file(ARGV[0]); data["packages"].sort_by{|p| p["id"]}.each{|p| puts [p["id"], p["group"], p["manager"]].join("\t") }' "$PACKAGES_FILE"
}
