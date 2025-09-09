if command -v kubebuilder >/dev/null 2>&1; then
	. <(kubebuilder completion bash)
elif [ -x "$HOME/.local/bin/kubebuilder" ]; then
    . <($HOME/.local/bin/kubebuilder completion bash)
fi
