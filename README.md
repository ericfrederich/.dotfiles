# Eric's dotfiles

## Prerequisites

Prior to running `stow` you must do the following.

Install [Oh My Bash](https://github.com/ohmybash/oh-my-bash).

```bash
# Copy of instructions from their README
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
```

Create a `~/.local/bin` directory.  This is required because we will later stow files that are in there.
If we don't do this then stow will symlink the directory instead of individual files.
If that happens new files placed inside of ~/.local/bin will make this repo dirty.

```bash
mkdir -p ~/.local/bin
```

## Installation

```bash
cd ~ && git clone https://github.com/ericfrederich/.dotfiles.git
cd ~/.dotfiles
sudo apt install -y stow
stow .
# change theme
perl -pi -e 's#OSH_THEME="font"#OSH_THEME="eric"#' ~/.bashrc
```
