# sucsn is short for a common pattern of running
#     sort | uniq -c | sort -n
#     ^      ^     ^   ^     ^
# but it does it efficiently in that the entire input doesn't need to be read and stored in memory by the sort command
# This awk command is similar but doesn't include the final sort -n
#     awk '{count[$0]++};END{for (k in count) print count[k], k}' | sort -n
alias sucsn="python3 -c \"import fileinput; from collections import Counter; c = Counter(line.removesuffix('\n') for line in fileinput.input()); print('\n'.join(f'{c}: {k}' for k, c in reversed(c.most_common())))\""

alias hili='python -m rich.syntax -b default'
alias tree='tree -I .git'
