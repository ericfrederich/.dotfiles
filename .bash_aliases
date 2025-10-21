# sucsn is short for a common pattern of running
#     sort | uniq -c | sort -n
#     ^      ^     ^   ^     ^
# but it does it efficiently in that the entire input doesn't need to be read and stored in memory by the sort command
# This awk command is similar but doesn't include the final sort -n
#     awk '{count[$0]++};END{for (k in count) print count[k], k}' | sort -n
alias sucsn="python3 -c \"import fileinput; from collections import Counter; c = Counter(line.removesuffix('\n') for line in fileinput.input()); print('\n'.join(f'{c}: {k}' for k, c in reversed(c.most_common())))\""
alias sucsnr="python3 -c \"import fileinput; from collections import Counter; c = Counter(line.removesuffix('\n') for line in fileinput.input()); print('\n'.join(f'{c}: {k}' for k, c in c.most_common()))\""

alias hili='python -m rich.syntax -b default'
alias tree='tree -I .git'

# Convert a newline delimited json file into an array
# for easier processing with JQ
# sed '1s/^/[/; $!s/$/,/; $s/$/]/'
alias nd2a="sed '1s/^/[/; \$!s/\$/,/; \$s/\$/]/'"

# Create an alias that takes args
# https://stackoverflow.com/a/42466441
# puse: "poetry use", set up a poetry project to use a specific version of python from pyenv
alias puse='f(){ [ "$#" -eq 1 ] || { echo "Need exactly one argument"; return 1; } && pyenv shell "$1" && poetry env use $(pyenv which python3) && pyenv shell --unset; unset -f f; }; f'

# print markdown
alias pmd='f(){ [ "$#" -eq 1 ] || { echo "Need exactly one argument"; return 1; } && python3 -c "from rich.console import Console; from rich.markdown import Markdown; Console().print(Markdown(open(\"$1\").read()))"; unset -f f; }; f'
