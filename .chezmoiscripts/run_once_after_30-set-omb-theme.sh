#!/bin/bash

set -euo pipefail

if [ -f "$HOME/.bashrc" ] && grep -q 'OSH_THEME="font"' "$HOME/.bashrc"; then
    echo -e "\033[33m┌────────────────────────────────────────────────────────────────────┐"
    echo -e "│                      Setting up Oh My Bash theme                   │"
    echo -e "│                                                                    │"
    echo -e "│  You'll need to exit bash and re-enter it for the theme changes    │"
    echo -e "│  to take effect.                                                   │"
    echo -e "└────────────────────────────────────────────────────────────────────┘\033[0m"
    echo
    perl -pi -e 's#OSH_THEME="font"#OSH_THEME="eric"#' "$HOME/.bashrc"
fi
