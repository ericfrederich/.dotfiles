# Rocky and Fedora don't add ~/.local/bin to PATH by default, so we need to do it manually.
if bash -c 'source /etc/os-release && echo $ID' | grep -Eq '^(rocky|fedora)$' && [[ ":$PATH:" != *"$HOME/.local/bin"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi
