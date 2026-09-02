#!/bin/bash

set -euo pipefail

# Install Oh My Bash if not already installed
if [ ! -d "$HOME/.oh-my-bash" ]; then
    echo "Installing Oh My Bash..."
    echo -e "\033[33m┌────────────────────────────────────────────────────────────────────┐"
    echo -e "│                                   WARNING                          │"
    echo -e "│                                                                    │"
    echo -e "│  This will enter you into a subshell. When you exit the subshell,  │"
    echo -e "│  the installation will complete.                                   │"
    echo -e "└────────────────────────────────────────────────────────────────────┘\033[0m"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
    echo
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
else
    echo "Oh My Bash already installed, skipping installation."
fi
