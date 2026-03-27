Edit `/opt/google/chrome/google-chrome` or whatever and add `--enable-blink-features=MiddleClickAutoscroll`

User: I'm trying to mimic WSL on Linux.
I've got this Incus setup where I can run graphical stuff like `gitk` or `tkdiff` inside of a container and I see it on my host system.
One of the things I'm currently missing is the ability to from within a container run `code .` and have VSCode on the host system open up the folder.
On Windows VSCode natively supports WSL through an extension so it's able to connect.
On Linux I can use "Remote-SSH" to manually do this... but I want it automatic.
I want to within a container (whether I've ssh'd into it or `incus exec`'d my way into it) be able to run `code .` and VSCode automatically start up, connect over ssh, and open the appropriate folder.

How can I achieve this?

GitHub Copilot:

## Approach: FIFO Bridge + SSH ProxyCommand

The core challenge is triggering the **host's** `code` CLI from inside the container. The VS Code CLI supports `code --remote ssh-remote+<host> <path>`, which opens a Remote-SSH window to the given host and folder. You need three pieces:

1. **A way for the container to send a request to the host** (shared FIFO)
2. **A host-side listener** that receives the request and runs `code --remote ...`
3. **SSH routing** so VS Code's Remote-SSH can connect back into the container

---

### 1. SSH ProxyCommand — Route SSH Through Incus

This lets VS Code's Remote-SSH connect to containers by name without needing to know their IP. Add to `~/.ssh/config` on the host:

```ssh-config
Host *.incus
    User ubuntu
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ProxyCommand incus exec $(echo %h | sed 's/\.incus$//') -- bash -c 'socat STDIO TCP:localhost:22'
```

Now `ssh mycontainer.incus` connects via `incus exec` — no IP resolution needed. (Requires `socat` inside the container; your cloud-init already installs it on apt-based systems, or add it to `dnf install`.)

---

### 2. Host-Side Listener Service

**Create the FIFO:**
```bash
mkfifo -m 600 "$HOME/.incus-code-fifo"
```

**Listener script** at `~/.local/bin/incus-code-listener`:
```bash
#!/bin/bash
FIFO="$HOME/.incus-code-fifo"
[[ -p "$FIFO" ]] || { echo "FIFO missing: $FIFO" >&2; exit 1; }

while true; do
    if read -r line < "$FIFO"; then
        host="${line%%:*}"
        path="${line#*:}"
        [[ -n "$host" && -n "$path" ]] && code --remote "ssh-remote+${host}" "$path" &
    fi
done
```

**Systemd user service** at `~/.config/systemd/user/incus-code-listener.service`:
```ini
[Unit]
Description=Incus VS Code Remote Listener

[Service]
ExecStart=%h/.local/bin/incus-code-listener
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
```

Enable it:
```bash
chmod +x ~/.local/bin/incus-code-listener
systemctl --user daemon-reload
systemctl --user enable --now incus-code-listener
```

---

### 3. Profile Changes (in `create-incus-gui-profile`)

**Add the FIFO as a disk device** (alongside your existing devices):
```bash
incus profile device add "$PROFILE_NAME" code-fifo disk \
    source="$HOME/.incus-code-fifo" path=/mnt/incus-code-fifo required=false
```

**Add the `code` shim to cloud-init `write_files`:**
```yaml
  - path: /usr/local/bin/code
    permissions: '0755'
    content: |
      #!/bin/bash
      FIFO="/mnt/incus-code-fifo"
      if [[ ! -p "$FIFO" ]]; then
          echo "Error: VS Code bridge not available" >&2
          exit 1
      fi
      CONTAINER="$(hostname).incus"
      if [[ $# -eq 0 || "$1" == "." ]]; then
          TARGET="$(pwd)"
      elif [[ "$1" == /* ]]; then
          TARGET="$1"
      else
          TARGET="$(cd "$1" 2>/dev/null && pwd || echo "$(pwd)/$1")"
      fi
      echo "${CONTAINER}:${TARGET}" > "$FIFO"
```

And add `socat` to the `dnf install` line in your `runcmd` section (it's likely already available on apt-based distros via a dependency, but explicitly adding it ensures the SSH ProxyCommand works):
```bash
dnf install -y ... socat
apt-get install -y ... socat
```

---

### How It Works End-to-End

1. User runs `code .` inside the container
2. The shim writes `mycontainer.incus:/home/ubuntu/project` to the shared FIFO
3. The host listener reads it and runs `code --remote ssh-remote+mycontainer.incus /home/ubuntu/project`
4. VS Code opens, the Remote-SSH extension connects to `mycontainer.incus` via the SSH ProxyCommand (which routes through `incus exec`)
5. VS Code opens the folder

This works identically whether you entered the container via `ssh` or `incus exec`, since the FIFO is always available as a mounted disk device.

---

### Notes

- **FIFO atomicity**: Writes under `PIPE_BUF` (4096 bytes) are atomic, so concurrent `code .` calls from multiple containers won't interleave.
- **Container hostname**: Incus sets the container hostname to the container name by default, so `$(hostname)` returns the right value.
- **`required=false`** on the disk device means the container still boots if the FIFO doesn't exist yet (same pattern you use for Xauthority).

User: I should have mentioned below is an example of how I currently connect to my incus containers over ssh.
I like having concrete entries in my ssh config for each incus container rather than a wildcard thing... this way those hosts appear in dropdowns if I want to connect to them through a GUI.
I don't believe that socat method would actually work anyway since VSCode and other things are expecting to be communicating with an actual ssh server.
My method is using sshd but not actually running it as a service or listening on port 22, it's a one-shot.

So please augment that style of command if anything else is needed.

```
Host ub24
    ProxyCommand incus exec ub24 -- /usr/sbin/sshd -i
```

GitHub Copilot:



Searched for text `regen.py`, no results

Searched for files matching `**/regen.py`, 1 match

Read [](file:///home/wwuh8r/.dotfiles/.ssh/config.d/regen.py#1-1), lines 1 to 100

Searched for files matching `**/.ssh/config*`, 1 match

Read [](file:///home/wwuh8r/.dotfiles/.ssh/config.d/regen.py#100-100), lines 100 to 173

Read [](file:///home/wwuh8r/.dotfiles/.ssh/config)

Good context. Your `sshd -i` ProxyCommand approach is solid — VS Code Remote-SSH works perfectly with it, and explicit entries are better for discoverability. Here's the revised plan that fits your existing infrastructure:

---

## Revised Architecture

Since your SSH config already has entries like `Host ub24` with the `sshd -i` ProxyCommand, VS Code can already connect to any container via `code --remote ssh-remote+ub24 /path`. The missing piece is just **triggering that from inside the container**.

### 1. Host-Side FIFO + Listener

**Create the FIFO:**
```bash
mkfifo -m 600 "$HOME/.incus-code-fifo"
```

**Listener script** at `~/.local/bin/incus-code-listener`:
```bash
#!/bin/bash
FIFO="$HOME/.incus-code-fifo"
[[ -p "$FIFO" ]] || { echo "FIFO missing: $FIFO" >&2; exit 1; }

while true; do
    while IFS= read -r line; do
        host="${line%%:*}"
        path="${line#*:}"
        if [[ -n "$host" && -n "$path" ]]; then
            code --remote "ssh-remote+${host}" "$path" &
        fi
    done < "$FIFO"
done
```

The outer `while true` re-opens the FIFO after all writers close; the inner `while read` processes each line. This avoids the race window of the simpler `read < FIFO` single-line pattern.

**Systemd user service** at `~/.config/systemd/user/incus-code-listener.service`:
```ini
[Unit]
Description=Incus VS Code Remote Listener

[Service]
ExecStart=%h/.local/bin/incus-code-listener
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
```

Enable:
```bash
chmod +x ~/.local/bin/incus-code-listener
systemctl --user daemon-reload
systemctl --user enable --now incus-code-listener
```

### 2. Profile Changes

Add the FIFO as a disk device in `create-incus-gui-profile`, alongside your existing devices:

```bash
incus profile device add "$PROFILE_NAME" code-bridge disk \
    source="$HOME/.incus-code-fifo" path=/mnt/incus-code-fifo required=false
```

Same `required=false` pattern you use for Xauthority — container boots fine even if the FIFO doesn't exist yet.

Add the `code` shim to the cloud-init `write_files`:

```yaml
  - path: /usr/local/bin/code
    permissions: '0755'
    content: |
      #!/bin/bash
      FIFO="/mnt/incus-code-fifo"
      if [[ ! -p "$FIFO" ]]; then
          echo "Error: VS Code bridge not available (host listener not running?)" >&2
          exit 1
      fi
      HOST="$(hostname)"
      if [[ $# -eq 0 || "$1" == "." ]]; then
          TARGET="$(pwd)"
      elif [[ "$1" == /* ]]; then
          TARGET="$1"
      else
          TARGET="$(cd "$1" 2>/dev/null && pwd || echo "$(pwd)/$1")"
      fi
      echo "${HOST}:${TARGET}" > "$FIFO"
```

### 3. How It Flows

```
container$ code .
  └─ shim writes "ub24:/home/ubuntu/project" to /mnt/incus-code-fifo
       └─ host listener reads from ~/.incus-code-fifo
            └─ runs: code --remote ssh-remote+ub24 /home/ubuntu/project
                 └─ VS Code opens, Remote-SSH connects using existing config:
                      Host ub24
                          ProxyCommand incus exec ub24 -- /usr/sbin/sshd -i
```

### Why This Works

- **`$(hostname)` = container name**: Incus sets hostname to the container name by default, and your regen.py creates SSH config entries keyed on the container name. So the shim's `hostname` output matches the `Host` entry in your SSH config exactly.
- **FIFO bind-mount**: Linux bind mounts preserve file type, so the FIFO works across the Incus mount boundary. The `raw.idmap` mapping (host UID → container UID 1000) means the container user can write to the host-owned FIFO.
- **No new SSH plumbing**: Everything routes through your existing `sshd -i` ProxyCommand entries. No socat, no port listening, no new network config.
- **`required=false`**: Same boot-resilience pattern as your Xauthority mount.

### Caveats

- **FIFO must exist before the listener starts**: The `mkfifo` is a one-time setup step. If the file gets deleted (e.g., during a cleanup), the listener and container writes will fail. You could add the `mkfifo` to the listener script as a safety check.
- **Container hostname customization**: If you ever rename a container or override its hostname to something different from its Incus name, the shim breaks. You could alternatively inject the container name via cloud-init or an environment variable set in the profile.
- **`code` CLI on host**: The host's `code` command must be in PATH for the systemd service. You may need to set `Environment=PATH=...` in the unit file or use the full path (usually `~/.local/bin/code` or code).
