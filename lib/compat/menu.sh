#!/usr/bin/env bash

compat_show_menu() {
  while true; do
    echo
    echo "Machine Setup Menu"
    echo "1) Install group (legacy compatibility)"
    echo "2) Install package"
    echo "3) List packages"
    echo "4) Doctor"
    echo "5) Exit"
    read -r -p "Choose an option [1-5]: " choice

    case "$choice" in
      1)
        compat_choose_group_and_install
        ;;
      2)
        compat_choose_package_and_install
        ;;
      3)
        cmd_list
        ;;
      4)
        cmd_doctor
        ;;
      5)
        break
        ;;
      *)
        echo "Invalid choice"
        ;;
    esac
  done
}

compat_choose_group_and_install() {
  local groups=()
  while IFS= read -r group; do
    groups+=("$group")
  done < <(list_groups)
  if [[ "${#groups[@]}" -eq 0 ]]; then
    log_warn "No groups found"
    return 0
  fi
  echo "Available groups:"
  local idx=1
  for g in "${groups[@]}"; do
    echo "  $idx) $g"
    idx=$((idx + 1))
  done
  read -r -p "Select group number: " pick
  if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#groups[@]} )); then
    log_error "Invalid group selection"
    return 1
  fi
  log_warn "Using legacy compatibility path: interactive group install"
  compat_install_group "${groups[pick-1]}"
}

compat_choose_package_and_install() {
  local pkgs=()
  while IFS= read -r pkg; do
    pkgs+=("$pkg")
  done < <(list_all_packages)
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    log_warn "No packages found"
    return 0
  fi
  echo "Available packages:"
  local idx=1
  for p in "${pkgs[@]}"; do
    echo "  $idx) $p"
    idx=$((idx + 1))
  done
  read -r -p "Select package number: " pick
  if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#pkgs[@]} )); then
    log_error "Invalid package selection"
    return 1
  fi
  compat_install_package "${pkgs[pick-1]}"
}
