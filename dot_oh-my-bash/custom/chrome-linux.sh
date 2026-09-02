patch-chrome-middleclickautoscroll() {
  local chrome_bin
  chrome_bin="$(realpath "$(command -v google-chrome)")" || {
    echo "error: google-chrome not found in PATH" >&2
    return 1
  }

  local expected='exec -a "$0" "$HERE/chrome" "$@"'
  local desired='exec -a "$0" "$HERE/chrome" --enable-blink-features=MiddleClickAutoscroll "$@"'
  local last_line
  last_line="$(tail -n 1 "$chrome_bin")"

  if [[ "$last_line" != "$expected" ]]; then
    echo "error: last line of $chrome_bin does not match expected pattern" >&2
    echo "  expected: $expected" >&2
    echo "  got:      $last_line" >&2
    return 1
  fi

  sudo cp "$chrome_bin" "${chrome_bin}.bak" || return 1
  sudo head -n -1 "${chrome_bin}.bak" > /tmp/chrome-patch.tmp || return 1
  printf '%s\n' "$desired" >> /tmp/chrome-patch.tmp || return 1
  sudo cp /tmp/chrome-patch.tmp "$chrome_bin" || return 1
  rm /tmp/chrome-patch.tmp

  echo "patched: $chrome_bin (backup: ${chrome_bin}.bak)"
}
