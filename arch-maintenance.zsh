#!/usr/bin/env zsh
set -euo pipefail

# Arch Maintenance Script
readonly version="1.0.3"
echo "Arch Maintenance Script v$version"

green=$(tput setaf 2)
red=$(tput setaf 1)
reset=$(tput sgr0)

function success() {
    echo -e "${green}[SUCCESS]${reset} $1"
}
function error() {
    echo -e "${red}[ERROR]${reset} $1" >&2
}

trap 'error "Script failed at line $LINENO."; exit 1' ERR

# Detect sudo usage
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Dependency check
function check_deps() {
    local miss=()
    for cmd in pacman paccache reflector flatpak fwupdmgr journalctl yay; do
        command -v $cmd &>/dev/null || miss+=($cmd)
    done
    if ((${#miss[@]})); then
        echo "⚠ Missing commands: ${miss[*]}. Some tasks will be skipped."
    fi
}

# Non-interactive --all
if [[ "${1:-}" == "--all" ]]; then
    check_deps
    perform_all_tasks
    exit 0
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [--all]"
    echo "  --all     Run all tasks without prompting"
    exit 0
fi

# Perform dependency check once
check_deps

# Update the system (and AUR) packages
function update_system() {
    if command -v yay &>/dev/null; then
        echo "Updating system & AUR packages with yay..."
        yay --noconfirm ||
            error "Failed to update via yay."
    else
        echo "Updating system packages with pacman..."
        $SUDO pacman -Syu --noconfirm || error "Failed to update system packages."
    fi
    success "System (and AUR) packages updated."
}

# Remove orphaned packages
function remove_orphans() {
    echo "Identifying orphaned dependencies..."
    local orphans
    orphans=$($SUDO pacman -Qdtq 2>/dev/null || true)
    if [[ -z "$orphans" ]]; then
        echo "No orphaned packages to remove."
        return
    fi
    echo "Orphaned packages found: $orphans"
    read "?Remove orphaned packages? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        echo "Removing orphaned packages..."
        $SUDO pacman -Rns --noconfirm $orphans || error "Failed to remove orphaned packages."
        success "Orphaned packages removed."
    else
        echo "Skipping orphan removal."
    fi
}

# Clear package cache (pacman -Scc)
function clear_cache() {
    echo "Clearing package cache..."
    $SUDO pacman -Scc --noconfirm || error "Failed to clear pacman cache."
    success "Package cache cleared."
}

# Clear package cache (paccache -ruk0) (*pacman-contrib required*)
function clear_paccache() {
    echo "Clearing package cache..."
    $SUDO paccache -ruk0 || error "Failed to clear package cache."
    success "Package cache cleared."
}

# Update Flatpak apps (*flatpak required*)
function update_flatpak() {
    echo "Updating Flatpak apps..."
    flatpak update -y || error "Failed to update Flatpak apps."
    success "Flatpak apps updated successfully."
}

# Remove unused Flatpak runtimes and extensions (*flatpak required*)
function unused_flatpak() {
    echo "Removing unused Flatpak runtimes and extensions..."
    flatpak uninstall --unused || error "Failed to remove unused Flatpak runtimes and extensions."
    success "Unused Flatpak runtimes and extensions removed successfully."
}

# Repair Flatpak (*flatpak required*)
function repair_flatpak() {
    echo "Repairing local Flatpak installation..."
    flatpak repair || error "Failed to repair local Flatpak installation"
    success "Local Flatpak installation successfully repaired."
}

# Clear Journal
function clear_journal() {
    echo "Clearing journal..."
    $SUDO journalctl --vacuum-time=4weeks || error "Failed to clear journal."
    success "Journal cleared."
}

# Update Arch Mirrors (*reflector required*)
function update_mirrors() {
    echo "Updating Mirrors using reflector"
    $SUDO reflector --country Romania --protocol https --age 12 --verbose --latest 20 --sort rate --save /etc/pacman.d/mirrorlist || error "Failed to update Arch Mirrors."
    success "Arch Mirrors updated successfully."
}

# Update firmware via fwupd (*fwupd required*)
function update_fwupd() {
    if ! command -v fwupdmgr &>/dev/null; then
        echo "Skipping firmware updates; fwupdmgr not found."
        return
    fi

    echo "Refreshing fwupd metadata..."
    $SUDO fwupdmgr refresh || error "Failed to refresh fwupd metadata."
    success "fwupd metadata refreshed."

    echo "Checking for fwupd updates..."
    local updates=$(fwupdmgr get-updates)
    if [[ -z "$updates" ]]; then
        echo "No firmware updates available."
    else
        read "?Apply firmware updates now? [y/N] " reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            $SUDO fwupdmgr update || error "Failed to apply firmware updates."
            success "Firmware updates applied."
        else
            echo "Skipped firmware updates."
        fi
    fi
}

# Clear user ~/.cache
function clear_home_cache() {
    echo "Clearing user cache at $HOME/.cache/..."
    if [[ -d "$HOME/.cache" ]]; then
        rm -rf "$HOME/.cache/"* || error "Failed to clear ~/.cache."
        success "~/.cache cleared."
    else
        echo "No ~/.cache directory found."
    fi
}

# Clear Steam appcache
function clear_steam_cache() {
    local http_cache="$HOME/.steam/steam/appcache/httpcache"
    local lib_cache="$HOME/.steam/steam/appcache/librarycache"
    echo "Clearing Steam HTTP cache at $http_cache..."
    if [[ -d "$http_cache" ]]; then
        rm -rf "$http_cache"/* || error "Failed to clear Steam HTTP cache."
        success "Steam HTTP cache cleared."
    else
        echo "No Steam HTTP cache directory found."
    fi
    echo "Clearing Steam Library cache at $lib_cache..."
    if [[ -d "$lib_cache" ]]; then
        rm -rf "$lib_cache"/* || error "Failed to clear Steam Library cache."
        success "Steam Library cache cleared."
    else
        echo "No Steam Library cache directory found."
    fi
}

# Perform all tasks (*flatpak pacman-contrib reflector required*)
function perform_all_tasks() {
    echo "Performing all tasks in order..."
    update_mirrors
    update_system
    update_flatpak
    unused_flatpak
    repair_flatpak
    update_fwupd
    remove_orphans
    clear_cache
    clear_paccache
    clear_journal
    clear_home_cache
    clear_steam_cache
    success "All tasks completed successfully."
}

# Interactive menu
function main() {
    while true; do
        echo
        echo "Select an action:"
        echo " 1) Update Arch Mirrors (*reflector required*)"
        echo " 2) Update the system (and AUR) packages, preferring yay if available"
        echo " 3) Update Flatpak apps (*flatpak required*)"
        echo " 4) Remove unused Flatpak runtimes and extensions (*flatpak required*)"
        echo " 5) Repair Flatpak (*flatpak required*)"
        echo " 6) Update firmware via fwupd (*fwupd required*)"
        echo " 7) Remove orphaned packages"
        echo " 8) Clear package cache (pacman -Scc)"
        echo " 9) Clear package cache (paccache -ruk0) (*pacman-contrib required*)"
        echo "10) Clear journal"
        echo "11) Clear user ~/.cache"
        echo "12) Clear Steam appcache"
        echo "13) Perform all tasks (*flatpak pacman-contrib reflector required*)"
        echo " 0) Exit"

        read "?Enter choice: " choice
        case $choice in
        1)
            update_mirrors
            ;;
        2)
            update_system
            ;;
        3)
            update_flatpak
            ;;
        4)
            unused_flatpak
            ;;
        5)
            repair_flatpak
            ;;
        6)
            update_fwupd
            ;;
        7)
            remove_orphans
            ;;
        8)
            clear_cache
            ;;
        9)
            clear_paccache
            ;;
        10)
            clear_journal
            ;;
        11)
            clear_home_cache
            ;;
        12)
            clear_steam_cache
            ;;
        13)
            perform_all_tasks
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            error "Invalid choice."
            ;;
        esac
    done
}

main
