#!/bin/zsh

version="1.0.1"
echo "Arch Maintenance Script v$version"

# Exit on error
set -e

# Defining colors
green=$(tput setaf 2)
red=$(tput setaf 1)
reset=$(tput sgr0)

# Function to print success messages
function success() {
    echo -e "${green}[SUCCESS]${reset} $1"
}

# Function to print error messages
function error() {
    echo -e "${red}[ERROR]${reset} $1" >&2
}

# Update the system
function update_system() {
    echo "Updating system packages..."
    sudo pacman -Syu --noconfirm || error "Failed to update system packages."
    success "System packages updated."
}

# Remove orphaned packages
function remove_orphans() {
    echo "Removing orphaned packages..."
    orphans=$(pacman -Qdtq)
    if [[ -z "$orphans" ]]; then
        echo "No orphaned packages to remove."
    else
        sudo pacman -Rns $orphans --noconfirm || error "Failed to remove orphaned packages."
        success "Orphaned packages removed."
    fi
}

# Clear package cache (pacman -Scc)
function clear_cache() {
    echo "Clearing package cache..."
    sudo pacman -Scc --noconfirm || error "Failed to clear package cache."
    success "Package cache cleared."
}

# Clear package cache (paccache -ruk0)
function clear_paccache() {
    echo "Clearing package cache..."
    sudo paccache -ruk0 || error "Failed to clear package cache."
    success "Package cache cleared."
}

# Update Flatpak apps
function update_flatpak() {
    echo "Updating Flatpak apps..."
    flatpak update -y || error "Failed to update Flatpak apps."
    success "Flatpak apps updated successfully."
}

# Remove unused Flatpak runtimes and extensions
function unused_flatpak() {
    echo "Removing unused Flatpak runtimes and extensions..."
    flatpak uninstall --unused || error "Failed to remove unused Flatpak runtimes and extensions."
    success "Unused Flatpak runtimes and extensions removed successfully."
}

# Repair Flatpak
function repair_flatpak() {
    echo "Repairing local Flatpak installation..."
    flatpak repair || error "Failed to repair local Flatpak installation"
    success "Local Flatpak installation successfully repaired."
}

# Clear Journal
function clear_journal() {
    echo "Clearing journal..."
    sudo journalctl --vacuum-time=4weeks || error "Failed to clear journal."
    success "Journal cleared."
}

# Update Arch Mirrors
function update_mirrors() {
    echo "Updating Mirrors using reflector"
    sudo reflector --protocol https --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist || error "Failed to update Arch Mirrors."
    success "Arch Mirrors updated successfully."
}

# Perform all tasks
function perform_all_tasks() {
    echo "Performing all maintenance tasks..."
    (
        update_mirrors &&
        update_system &&
        remove_orphans &&
        clear_cache &&
        clear_paccache &&
        update_flatpak &&
        unused_flatpak &&
        repair_flatpak &&
        clear_journal
    ) || error "Failed to perform all tasks."
    success "All tasks completed successfully."
}

# Main menu
function main() {
    while true; do
        echo "Select an action:"
        echo "1) Update system packages"
        echo "2) Remove orphaned packages"
        echo "3) Clear package cache (pacman -Scc)"
        echo "4) Clear package cache (paccache -ruk0)"
        echo "5) Update Flatpak apps"
        echo "6) Remove unused Flatpak runtimes and extensions"
        echo "7) Repair Flatpak"
        echo "8) Clear journal"
        echo "9) Update Arch Mirrors"
        echo "10) Perform all tasks"
        echo "0) Exit"

        echo -n "Enter your choice: "
        read choice
        case $choice in
        1)
            update_system
            ;;
        2)
            remove_orphans
            ;;
        3)
            clear_cache
            ;;
        4)
            clear_paccache
            ;;
        5)
            update_flatpak
            ;;
        6)
            unused_flatpak
            ;;
        7)
            repair_flatpak
            ;;
        8)
            clear_journal
            ;;
        9)
            update_mirrors
            ;;
        10)
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
        echo
    done
}

main
