#!/usr/bin/env bash
set -euo pipefail

install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh already installed"
    return 0
  fi
  run_eval "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
}

install_zsh_plugin() {
  local repo="$1"
  local dest="$2"
  if [[ -d "$dest" ]]; then
    log_info "plugin already present: $dest"
    return 0
  fi
  run_eval "git clone '$repo' '$dest'"
}

install_fzf_extras() {
  if [[ -f "/opt/homebrew/opt/fzf/install" ]]; then
    run_eval "yes | /opt/homebrew/opt/fzf/install --all"
  else
    log_warn "fzf install helper not found at /opt/homebrew/opt/fzf/install"
  fi
}

apply_dotfile_mapping() {
  local mapping_file="$ROOT_DIR/dotfiles/mapping.yaml"
  ruby -ryaml -e '
    data=YAML.load_file(ARGV[0])
    data["mappings"].each do |m|
      src=File.expand_path(m["source"], ARGV[1])
      dst=File.expand_path(m["target"])
      puts [src,dst,m["mode"]].join("\t")
    end
  ' "$mapping_file" "$ROOT_DIR" | while IFS=$'\t' read -r src dst mode; do
      if [[ ! -f "$src" ]]; then
        log_warn "missing source dotfile: $src"
        continue
      fi
      if [[ -e "$dst" && ! -e "$dst.setup.bak" ]]; then
        run_eval "cp '$dst' '$dst.setup.bak'"
      fi
      if [[ "$mode" == "copy" ]]; then
        run_eval "cp '$src' '$dst'"
      else
        run_eval "ln -sfn '$src' '$dst'"
      fi
      log_info "applied dotfile mapping: $dst"
    done
}
