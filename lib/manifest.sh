#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_FILE="${PACKAGES_FILE:-$ROOT_DIR/manifests/packages.yaml}"
GROUPS_FILE="${GROUPS_FILE:-$ROOT_DIR/manifests/groups.yaml}"
TAGS_FILE="${TAGS_FILE:-$ROOT_DIR/manifests/tags.yaml}"

# Uses macOS system Ruby Psych parser for YAML so we don't depend on yq/jq.
ruby_manifest() {
  ruby -ryaml -rjson -e "$1" "$2"
}

package_ruby_manifest() {
  ruby_manifest "$1" "$PACKAGES_FILE"
}

tags_ruby_manifest() {
  ruby_manifest "$1" "$TAGS_FILE"
}

list_groups() {
  ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data["groups"].keys.sort' "$GROUPS_FILE"
}

list_group_packages() {
  local group="$1"
  ruby_manifest 'data=YAML.load_file(ARGV[0]); arr=data.dig("groups",ENV["GROUP"],"packages") || []; puts arr' "$GROUPS_FILE"
}

list_all_packages() {
  package_ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data.fetch("packages", []).map{|p| p["id"]}.sort'
}

list_all_tags() {
  tags_ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data.fetch("tags", []).map{|t| t["id"]}.sort'
}

package_exists() {
  local pkg="$1"
  PKG="$pkg" package_ruby_manifest 'data=YAML.load_file(ARGV[0]); ids=data.fetch("packages", []).map{|p| p["id"]}; exit(ids.include?(ENV["PKG"]) ? 0 : 1)'
}

tag_exists() {
  local tag="$1"
  TAG="$tag" tags_ruby_manifest 'data=YAML.load_file(ARGV[0]); ids=data.fetch("tags", []).map{|t| t["id"]}; exit(ids.include?(ENV["TAG"]) ? 0 : 1)'
}

package_field() {
  local pkg="$1"
  local field="$2"
  PKG="$pkg" FIELD="$field" package_ruby_manifest '
    data=YAML.load_file(ARGV[0])
    p=data.fetch("packages", []).find{|x| x["id"]==ENV["PKG"]}
    exit 0 if p.nil?

    keys=ENV["FIELD"].split(".")
    v=keys.reduce(p) do |acc, key|
      break nil unless acc.is_a?(Hash)
      acc[key]
    end

    if v.nil? && !ENV["FIELD"].include?(".")
      legacy_map={
        "manager" => p.dig("installer", "kind"),
        "install" => p.dig("installer", "package"),
        "check" => p.dig("check", "command")
      }
      v=legacy_map[ENV["FIELD"]]
    end

    if v.nil?
      exit 0
    elsif v.is_a?(Array)
      puts v.join("\n")
    else
      puts v
    end
  '
}

package_dependencies() {
  local pkg="$1"
  PKG="$pkg" package_ruby_manifest 'data=YAML.load_file(ARGV[0]); p=data.fetch("packages", []).find{|x| x["id"]==ENV["PKG"]}; arr=(p && p["depends_on"]) || []; puts arr'
}

package_tags() {
  local pkg="$1"
  PKG="$pkg" package_ruby_manifest 'data=YAML.load_file(ARGV[0]); p=data.fetch("packages", []).find{|x| x["id"]==ENV["PKG"]}; arr=(p && p["tags"]) || []; puts arr'
}

tag_packages() {
  local tag="$1"
  TAG="$tag" package_ruby_manifest '
    data=YAML.load_file(ARGV[0])
    data.fetch("packages", []).select{|p| (p["tags"] || []).include?(ENV["TAG"]) }.map{|p| p["id"]}.sort.each{|id| puts id }
  '
}

package_installer_kind() {
  package_field "$1" "installer.kind"
}

package_install_target() {
  package_field "$1" "installer.package"
}

package_check_command() {
  package_field "$1" "check.command"
}

package_config_optional() {
  package_field "$1" "config.optional"
}

package_summary_table() {
  package_ruby_manifest 'data=YAML.load_file(ARGV[0]); data.fetch("packages", []).sort_by{|p| p["id"]}.each{|p| puts [p["id"], p["group"], p.dig("installer", "kind")].join("\t") }'
}

manifest_schema_version() {
  package_ruby_manifest 'data=YAML.load_file(ARGV[0]); puts data["schema_version"]'
}

validate_manifest_schema() {
  package_ruby_manifest '
    data=YAML.load_file(ARGV[0])
    errors=[]
    schema_version=data["schema_version"]
    errors << "packages.yaml: schema_version must be 1" unless schema_version == 1

    packages=data.fetch("packages", [])
    ids=packages.map{|p| p["id"]}.compact
    duplicate_ids=ids.group_by{|id| id}.select{|_, arr| arr.length > 1}.keys
    duplicate_ids.each{|id| errors << "packages.yaml: duplicate package id #{id}" }

    packages.each do |pkg|
      id=pkg["id"] || "<missing-id>"
      installer=pkg["installer"] || {}
      check=pkg["check"] || {}

      errors << "packages.yaml: #{id} missing installer.kind" if installer["kind"].to_s.empty?
      errors << "packages.yaml: #{id} missing installer.package" if installer["package"].to_s.empty?
      errors << "packages.yaml: #{id} missing check.command" if check["command"].to_s.empty?

      (pkg["depends_on"] || []).each do |dep|
        unless ids.include?(dep)
          errors << "packages.yaml: #{id} depends_on unknown package #{dep}"
        end
      end

      config=pkg["config"] || {}
      strategy=config["strategy"]
      if !strategy.nil? && strategy != "chezmoi_tag"
        errors << "packages.yaml: #{id} has unsupported config strategy #{strategy}"
      end
    end

    if !errors.empty?
      warn errors.join("\n")
      exit 1
    end
  '

  tags_ruby_manifest '
    data=YAML.load_file(ARGV[0])
    errors=[]
    schema_version=data["schema_version"]
    errors << "tags.yaml: schema_version must be 1" unless schema_version == 1

    tags=data.fetch("tags", [])
    ids=tags.map{|t| t["id"]}.compact
    duplicate_ids=ids.group_by{|id| id}.select{|_, arr| arr.length > 1}.keys
    duplicate_ids.each{|id| errors << "tags.yaml: duplicate tag id #{id}" }

    if !errors.empty?
      warn errors.join("\n")
      exit 1
    end
  '
}
