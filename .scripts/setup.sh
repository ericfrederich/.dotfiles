#!/bin/bash

set -euo pipefail

# Assert that this script is being executed from the correct location
script_path=$(realpath "${BASH_SOURCE[0]}")
expected_path="$HOME/.dotfiles/.scripts/setup.sh"
if [[ "$script_path" != "$expected_path" ]]; then
    echo "Error: This script must be executed as ~/.dotfiles/.scripts/setup.sh"
    echo "Current resolved path: $script_path"
    echo "Expected path: $expected_path"
    exit 1
fi

# Set install command based on available package manager
install_command=""
for cmd in "nala install -y" "apt install -y" "dnf install -y"; do
    package_manager=$(echo "$cmd" | cut -d' ' -f1)
    if command -v "$package_manager" &> /dev/null; then
        install_command="$cmd"
        break
    fi
done

if [ -z "$install_command" ]; then
    echo "Error: No supported package manager found (nala, apt, or dnf)"
    exit 1
fi

echo "Using package manager: $install_command"

required_packages="curl git stow perl"

# Install required packages
echo "Installing required packages: $required_packages"
sudo $install_command $required_packages

# Install keychain if running inside WSL
if grep -qEi "(microsoft|wsl)" /proc/version &> /dev/null; then
    sudo $install_command keychain
fi

# Install Oh My Bash if not already installed
if [ ! -d ~/.oh-my-bash ]; then
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

# Create a `~/.local/bin` directory.  This is required because we will later stow files that are in there.
# If we don't do this then stow will symlink the directory instead of individual files.
# If that happens new files placed inside of ~/.local/bin will make this repo dirty.
mkdir -p ~/.local/bin

cd ~/.dotfiles
stow .

# Configure Git user settings
echo "Checking Git configuration..."

# Check if user.name is set
if ! git config --get user.name &> /dev/null; then
    echo "Git user.name is not set."

    echo "Enter your DISPLAY name for git."
    echo "This is not your username, but something like \"John Doe\"."
    read -p "name (without quotes): " username

    git config -f ~/.gitconfig.local user.name "$username"
    echo "Git user.name set to: $username"
else
    echo "Git user.name is already set to: $(git config --get user.name)"
fi

# Check if user.email is set
if ! git config --get user.email &> /dev/null; then
    echo "Git user.email is not set."
    read -p "Please enter your Git email: " email
    git config -f ~/.gitconfig.local user.email "$email"
    echo "Git user.email set to: $email"
else
    echo "Git user.email is already set to: $(git config --get user.email)"
fi

echo -e "\033[33m┌────────────────────────────────────────────────────────────────────┐"
echo -e "│                      Setting up Oh My Bash theme                   │"
echo -e "│                                                                    │"
echo -e "│  You'll need to exit bash and re-enter it for the theme changes    │"
echo -e "│  to take effect.                                                   │"
echo -e "└────────────────────────────────────────────────────────────────────┘\033[0m"
echo
perl -pi -e 's#OSH_THEME="font"#OSH_THEME="eric"#' ~/.bashrc
