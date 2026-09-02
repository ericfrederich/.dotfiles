if command -v kubectl >/dev/null 2>&1; then
    . <(kubectl completion bash)
elif [ -x "$HOME/.local/bin/kubectl" ]; then
    . <($HOME/.local/bin/kubectl completion bash)
fi
