if [ -n "$WSL_DISTRO_NAME" ]; then

# https://stackoverflow.com/questions/52423626/remember-git-passphrase-in-wsl
keychain --nogui ~/.ssh/id_rsa
. ~/.keychain/$(hostname)-sh

export GPG_TTY=$(tty)

# # https://github.com/jaraco/keyring/issues/566#issuecomment-1792544475
# # wait for systemd --user dbus session and unlock keyring
# sleep 1
# eval $(echo -n db | gnome-keyring-daemon --unlock --replace 2> /dev/null)

export BROWSER='/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'

fi
