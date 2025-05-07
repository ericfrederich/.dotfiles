# Rocky doesn't add ~/.local/bin to PATH by default, so we need to do it manually.

# Add ~/.local/bin to PATH if it exists and is not already included
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *"$HOME/.local/bin"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi
