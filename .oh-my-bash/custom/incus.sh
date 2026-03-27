# This is to more easily pass Xauthority into incus containers.
# Normally, the file is named differently on each boot.
# We use a symlink with a static name that we update on the host at login.
# We then pass this static path into the container, so it can always find the Xauthority file regardless of its actual name on the host.

if [ -n "$XAUTHORITY" ]; then
    ln -sf "$XAUTHORITY" "$HOME/.Xauthority-incus"
fi

change-incus-user() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: change-incus-user <container_name> <user_from> <user_to>"
        echo "  Renames a user inside an Incus container, including home directory and sudoers entry."
        return 1
    fi

    local container_name="$1"
    local user_from="$2"
    local user_to="$3"

    echo "Changing $user_from to $user_to in $container_name..."

    incus exec "$container_name" -- usermod -l "$user_to" "$user_from" || {
        echo "Failed to rename user $user_from to $user_to"
        return 1
    }
    incus exec "$container_name" -- usermod -d "/home/$user_to" -m "$user_to" || {
        echo "Failed to move home directory to /home/$user_to"
        return 1
    }
    incus exec "$container_name" -- groupmod -n "$user_to" "$user_from" || {
        echo "Failed to rename group $user_from to $user_to"
        return 1
    }
    incus exec "$container_name" -- bash -c "echo '$user_to ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$user_to" || {
        echo "Failed to update sudoers for $user_to"
        return 1
    }
}

create-incus-gui-profile() {
    local PROFILE_NAME="${1:-gui}"
    local SSH_PUB_KEY_FILE="${HOME}/.ssh/id_ed25519.pub"
    local XAUTH_STATIC="${HOME}/.Xauthority-incus"
    local LSL_FIFO="${HOME}/.lsl-fifo"
    local SHIM_DIR
    SHIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lsl-shims" && pwd)"

    if [[ "$#" -gt 1 ]]; then
        echo "Usage: $0 [profile-name]" >&2
        return 1
    fi

    if [[ ! -f "$SSH_PUB_KEY_FILE" ]]; then
        echo "Error: required SSH public key not found at $SSH_PUB_KEY_FILE" >&2
        return 1
    fi

    if [[ ! -L "$XAUTH_STATIC" ]]; then
        cat >&2 <<'EOF'
Error: required Xauthority symlink is missing at $HOME/.Xauthority-incus

Add this to your ~/.bashrc and open a new shell (or source ~/.bashrc):
if [ -n "$XAUTHORITY" ]; then
    ln -sf "$XAUTHORITY" "$HOME/.Xauthority-incus"
fi
EOF
        return 1
    fi

    if incus profile list -f csv -cn | grep -qxF "$PROFILE_NAME"; then
        echo "Error: Incus profile '$PROFILE_NAME' already exists..." >&2
        return 1
    fi

    # Strict error handling – restored automatically when the function returns
    local _saved_errtrap
    _saved_errtrap=$(trap -p ERR)
    set -Euo pipefail
    trap 'echo "Error: command failed: ${BASH_COMMAND}" >&2; return 1' ERR
    trap 'set +Euo pipefail; eval "${_saved_errtrap:-trap - ERR}"; trap - RETURN' RETURN

    incus profile create "$PROFILE_NAME" --description "Automagic GUI profile for X11 and GPU access"

    # Enable nesting and allow the container to manage its own sysctls/mounts
    # This allows us to run docker inside of the container
    incus profile set "$PROFILE_NAME" security.nesting=true
    incus profile set "$PROFILE_NAME" security.syscalls.intercept.mknod=true

    # Setup ID mapping (Maps host user to most container's default users that use UID/GID 1000)
    printf "uid $(id -u) 1000\ngid $(id -g) 1000" | incus profile set "$PROFILE_NAME" raw.idmap -

    # Devices
    incus profile device add "$PROFILE_NAME" X11 disk source=/tmp/.X11-unix path=/mnt/.X11-unix

    # Point Incus to the STATIC symlink
    #
    # By setting required=false, the container will boot as soon as the host does.
    # If you try to run a GUI app immediately after the host boots (before you've logged into the host desktop),
    # the GUI app might fail because the Xauth file is "missing" inside the container.
    #
    # However, as soon as you log into your host desktop and your script (or a login hook) updates that $XAUTH_STATIC symlink,
    # the container will "see" the file (because Incus disk mounts are live pointers),
    # and GUIs will start working without needing to restart the container.
    incus profile device add "$PROFILE_NAME" Xauth disk source="$XAUTH_STATIC" path=/mnt/Xauthority required=false

    # Enable GPU
    incus profile device add "$PROFILE_NAME" mygpu gpu

    # LSL bridge – lets containers trigger host-side actions (VS Code, browser, etc.)
    incus profile device add "$PROFILE_NAME" lsl-bridge disk source="$LSL_FIFO" path=/mnt/lsl-fifo required=false

    # Read LSL shim scripts, indented for YAML embedding
    local CODE_SHIM BROWSER_SHIM
    CODE_SHIM=$(sed 's/^/      /' "$SHIM_DIR/code")
    BROWSER_SHIM=$(sed 's/^/      /' "$SHIM_DIR/lsl-browser")

    # Cloud-Init for GUI Plumbing
    incus profile set "$PROFILE_NAME" user.user-data - <<EOF
#cloud-config
package_update: true

ssh_authorized_keys:
  - $(<"$SSH_PUB_KEY_FILE")

write_files:
  - path: /etc/profile.d/gui-env.sh
    content: |
      export DISPLAY=$DISPLAY
      export XAUTHORITY=/mnt/Xauthority
      export BROWSER=/usr/local/bin/lsl-browser
      export GPG_TTY=\$(tty)
      keychain --nogui
      . ~/.keychain/\$(hostname)-sh
  # Fix for GUI surviving reboot
  - path: /etc/fstab
    append: true
    content: |
      /mnt/.X11-unix /tmp/.X11-unix none defaults,bind,allow_other,x-systemd.requires=/mnt/.X11-unix 0 0
  # Fix for VSCode SSH surviving reboot
  - path: /etc/tmpfiles.d/sshd.conf
    content: |
      d /run/sshd 0755 root root -
  - path: /etc/tmpfiles.d/preserve-x11.conf
    content: |
      x /tmp/.X11-unix
      x /tmp/.X11-unix/*
  # LSL bridge shims – write to host FIFO to trigger host-side actions
  - path: /usr/local/bin/code
    permissions: '0755'
    content: |
$CODE_SHIM
  - path: /usr/local/bin/lsl-browser
    permissions: '0755'
    content: |
$BROWSER_SHIM

runcmd:
  # 1. Fix the X11 Socket
  - mkdir -p /tmp/.X11-unix
  # Optional: ensure permissions are correct for the socket folder
  - chmod 1777 /tmp/.X11-unix
  # Mount it for the first boot (subsequently, the fstab entry will take care of it)
  - mount --bind /mnt/.X11-unix /tmp/.X11-unix

  # 2. Setup SSH "One-Shot" requirements
  - mkdir -p /run/sshd
  - chmod 0755 /run/sshd
  - ssh-keygen -A  # Generates host keys so sshd doesn't complain

  # 3. Smart Package Installation
  - |
    if command -v dnf >/dev/null; then
      dnf install -y xclock glx-utils mesa-dri-drivers xterm openssh-server
    elif command -v apt-get >/dev/null; then
      apt-get install -y x11-apps mesa-utils libgl1-mesa-dri xterm rsync openssh-server
    else
      echo "No supported package manager found (expected dnf or apt-get)." >&2
      exit 1
    fi
EOF
}
