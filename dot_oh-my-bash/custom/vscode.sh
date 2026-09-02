# Allow vscode agents to execute commands
# oh-my-bash breaks VSCode's ability to detect when a command has finished
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  unset PROMPT_COMMAND
  PS1='\w \$ '
fi
