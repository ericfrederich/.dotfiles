for file in ~/.deno/env ~/.local/share/bash-completion/completions/deno.bash; do
    [ -f "$file" ] && source "$file"
done
