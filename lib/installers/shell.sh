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
  local fzf_prefix=""
  local fzf_install=""

  if command_exists brew; then
    fzf_prefix="$(brew --prefix fzf 2>/dev/null || true)"
  fi

  if [[ -n "$fzf_prefix" ]]; then
    fzf_install="$fzf_prefix/install"
  fi

  if [[ -z "$fzf_install" || ! -f "$fzf_install" ]]; then
    log_warn "fzf install helper not found via brew prefix"
    return 0
  fi

  run_eval "yes | '$fzf_install' --all"
}

shell_component_install() {
  local component="$1"

  case "$component" in
    oh-my-zsh)
      install_oh_my_zsh
      ;;
    zsh-syntax-highlighting)
      install_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
      ;;
    zsh-autosuggestions-plugin)
      install_zsh_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
      ;;
    zsh-z)
      install_zsh_plugin "https://github.com/agkozak/zsh-z" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-z"
      ;;
    fzf-extra)
      install_fzf_extras
      ;;
    *)
      log_error "Unknown shell component handler for $component"
      return 1
      ;;
  esac
}
