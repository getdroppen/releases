#!/bin/sh
# Droppen installer for macOS: https://github.com/getdroppen/releases
#
# This installs the Droppen server, to run in the background or on a headless
# Mac. For everyday use the Droppen desktop App, on the same releases page, is
# the recommended way.
#
#   curl -fsSL https://droppen.app/install.sh | sh                    install or upgrade
#   curl -fsSL https://droppen.app/install.sh | sh -s -- --uninstall  uninstall (keeps your data)
#
# What it does, for the macOS user who runs it (no sudo):
#   1. downloads the latest release (or $DROPPEN_VERSION) from
#      github.com/getdroppen/releases and checks it against the release's SHA256SUMS;
#   2. installs the server to ~/.local/share/remote-hand/bin/remote-hand-server;
#   3. creates the first account for the local page (you choose the password;
#      one is generated and shown once only when there is no terminal to ask on);
#   4. registers a launchd user agent (app.droppen.server) that starts the server
#      at login and restarts it if it stops, on 127.0.0.1:8700 or the next free port;
#   5. waits until the server answers and refuses visitors without a login, then
#      opens http://127.0.0.1:<port> in your browser.
#
# Running it again upgrades in place and keeps your data. It never touches a
# Droppen (remote-hand) server it did not install itself: it lists what it
# found and leaves it alone.
#
# Settings, all optional:
#   DROPPEN_VERSION=v0.2.118   install this release instead of the latest
#   DROPPEN_PORT=8700          the first port to try on a new install
#   DROPPEN_USER=name          the first account's name (default: your macOS user name)
#   DROPPEN_NO_OPEN=1          do not open the browser
#   DROPPEN_SERVICE_PATH=...   the PATH the server runs with (default: common
#                              tool directories plus your current PATH)
#   DROPPEN_RELEASE_BASE=...   where releases come from
#                              (default https://github.com/getdroppen/releases/releases)
#   DROPPEN_LABEL=...          the launchd label (default app.droppen.server)
#
# The binary, its data and its commands are still named remote-hand; they take
# the Droppen name when the source is published at github.com/getdroppen/droppen.

set -eu

RELEASES_URL=https://github.com/getdroppen/releases
INSTALL_CMD="curl -fsSL https://droppen.app/install.sh | sh"
BASE=${DROPPEN_RELEASE_BASE:-$RELEASES_URL/releases}
LABEL=${DROPPEN_LABEL:-app.droppen.server}
# The instance this installer owns: `default`, the name a server takes when
# nothing says otherwise. Two servers on one Mac need different instances.
INSTANCE=default
BIN_NAME=remote-hand-server

say() { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Droppen installer for macOS: the server, for background and headless use.
For everyday use, the Droppen desktop App is recommended:
https://github.com/getdroppen/releases/releases/latest

  curl -fsSL https://droppen.app/install.sh | sh                    install or upgrade
  curl -fsSL https://droppen.app/install.sh | sh -s -- --uninstall  uninstall (keeps your data)

Settings: DROPPEN_VERSION, DROPPEN_PORT, DROPPEN_USER, DROPPEN_NO_OPEN=1,
DROPPEN_SERVICE_PATH, DROPPEN_RELEASE_BASE, DROPPEN_LABEL.
More: https://github.com/getdroppen/releases#readme
EOF
}

# ---------------------------------------------------------------- places

set_paths() {
  case "${HOME:-}" in
    /*) ;;
    *) die "HOME is not set to an absolute path" ;;
  esac
  DATA_DIR=$HOME/.local/share/remote-hand
  CONFIG_DIR=$HOME/.config/remote-hand
  BIN_DIR=$DATA_DIR/bin
  BIN=$BIN_DIR/$BIN_NAME
  PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
  LOG_DIR=$HOME/Library/Logs/remote-hand
  # What this installer writes to recognise its own install on the next run.
  MARKER=$CONFIG_DIR/droppen-install.env
  DOMAIN=gui/$(id -u)
}

marker_get() { # key
  [ -f "$MARKER" ] || return 0
  sed -n "s/^$1=//p" "$MARKER" | head -n 1
}

ours() { [ -f "$MARKER" ] && [ "$(marker_get label)" = "$LABEL" ]; }

loaded() { launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; }

# The binary, run the way launchd runs it: from $HOME, with nothing of this
# shell's environment (an APP_INSTANCE or APP_HOME_DIR here must not redirect it).
run_bin() {
  (cd "$HOME" && env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG="${LANG:-en_US.UTF-8}" "$BIN" "$@")
}

# ---------------------------------------------------------------- checks

check_platform() {
  case "$(uname -s)" in
    Darwin) ;;
    Linux)
      say "Droppen for Linux is coming soon. This installer supports macOS only for now."
      say "Droppen 的 Linux 版即将推出，目前安装脚本只支持 macOS。"
      say "Follow $RELEASES_URL for the Linux release."
      exit 1 ;;
    *) die "this installer supports macOS only (found $(uname -s))" ;;
  esac
  [ "$(id -u)" -ne 0 ] || die "run this as yourself, not as root (no sudo): Droppen runs as your user"
  case "$(uname -m)" in
    arm64) ARCH=aarch64 ;;
    x86_64)
      # A shell under Rosetta reports x86_64 on Apple silicon; install the native one.
      if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then ARCH=aarch64; else ARCH=x86_64; fi ;;
    *) die "unsupported Mac architecture: $(uname -m)" ;;
  esac
  for tool in curl shasum tar launchctl plutil lsof sed awk; do
    command -v "$tool" >/dev/null 2>&1 || die "missing $tool"
  done
}

# Every other Droppen (remote-hand) server this user has: loaded launchd jobs
# and agent plists. Sets OTHERS (a printable list) and CONFLICT (why this
# install would touch one of them; empty when it would not).
find_others() {
  OTHERS=""
  CONFLICT=""
  for job in $(launchctl list 2>/dev/null | awk 'NR > 1 { print $3 }' | grep -iE 'remote-hand|droppen' || true); do
    [ "$job" = "$LABEL" ] && continue
    info=$(launchctl print "$DOMAIN/$job" 2>/dev/null || true)
    program=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*program = //p' | head -n 1)
    port=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*APP_SERVER__PORT => //p' | head -n 1)
    OTHERS="$OTHERS
    $job (launchd, port ${port:-8700}, ${program:-unknown program})"
    if [ "$program" = "$BIN" ]; then
      CONFLICT="the launchd job $job runs $BIN, which this installer would replace"
    fi
  done
  for plist in "$HOME"/Library/LaunchAgents/*.plist; do
    [ -f "$plist" ] || continue
    [ "$plist" = "$PLIST" ] && continue
    grep -qE 'remote-hand|droppen' "$plist" 2>/dev/null || continue
    job=$(basename "$plist" .plist)
    case "$OTHERS" in *"    $job "*) ;; *) OTHERS="$OTHERS
    $job (launchd agent, not loaded: $plist)" ;; esac
    if grep -qF "$BIN" "$plist"; then
      CONFLICT="$plist runs $BIN, which this installer would replace"
    fi
  done
  if [ -z "$CONFLICT" ] && ! ours; then
    if [ -e "$BIN" ]; then
      CONFLICT="$BIN exists, but this installer did not put it there"
    elif [ -d "$DATA_DIR/instances" ]; then
      CONFLICT="$DATA_DIR already holds the data of a Droppen server this installer did not create"
    fi
  fi
}

report_others() {
  [ -n "$OTHERS" ] || return 0
  say ""
  say "Other Droppen (remote-hand) servers on this Mac, left alone:$OTHERS"
}

refuse_conflict() {
  report_others
  say ""
  say "Found an existing install: $CONFLICT."
  say "发现已有的安装，本脚本不会改动它。"
  say "Nothing was changed. This installer only manages a server it installed itself"
  say "(launchd label $LABEL). Keep using the existing one, or remove it first."
  exit 1
}

# ---------------------------------------------------------------- download

resolve_version() {
  if [ -n "${DROPPEN_VERSION:-}" ]; then
    VERSION=$DROPPEN_VERSION
    case "$VERSION" in v*) ;; *) VERSION=v$VERSION ;; esac
  else
    # GitHub answers /releases/latest with a redirect to /releases/tag/<tag>.
    url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$BASE/latest") \
      || die "could not reach $BASE/latest to find the latest release"
    VERSION=${url##*/tag/}
    [ "$VERSION" != "$url" ] || die "could not find the latest release at $BASE/latest"
  fi
  printf '%s\n' "$VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' \
    || die "not a release version: $VERSION"
}

download_and_verify() {
  ASSET=remote-hand-$VERSION-macos-$ARCH.tar.gz
  case "$BASE" in
    https://*) ;;
    *) warn "downloading over plain HTTP from $BASE (DROPPEN_RELEASE_BASE)" ;;
  esac
  step "Downloading Droppen $VERSION for $ARCH"
  curl -fsSL --retry 3 -o "$TMP/$ASSET" "$BASE/download/$VERSION/$ASSET" \
    || die "could not download $BASE/download/$VERSION/$ASSET"
  curl -fsSL --retry 3 -o "$TMP/SHA256SUMS" "$BASE/download/$VERSION/SHA256SUMS" \
    || die "could not download $BASE/download/$VERSION/SHA256SUMS"

  # Lines are `<sha256>  ./<file>` (or without the ./, or with a * for binary mode).
  expected=$(awk -v f="$ASSET" '{ n = $2; sub(/^\*/, "", n); sub(/^\.\//, "", n); if (n == f) { print $1; exit } }' "$TMP/SHA256SUMS")
  printf '%s\n' "$expected" | grep -Eq '^[0-9a-f]{64}$' || die "SHA256SUMS of $VERSION has no entry for $ASSET"
  actual=$(shasum -a 256 "$TMP/$ASSET" | awk '{ print $1 }')
  [ "$actual" = "$expected" ] || die "checksum mismatch for $ASSET (expected $expected, got $actual); nothing was installed"
  say "SHA-256 verified: $actual"

  mkdir "$TMP/x"
  tar -xzf "$TMP/$ASSET" -C "$TMP/x" "$BIN_NAME" || die "$ASSET does not contain $BIN_NAME"
  NEW=$TMP/x/$BIN_NAME
  chmod 755 "$NEW"
  xattr -d com.apple.quarantine "$NEW" 2>/dev/null || true
  NEW_VERSION=$("$NEW" --version 2>/dev/null) || die "the downloaded server does not run on this Mac"
}

# ---------------------------------------------------------------- install

port_busy() { # port
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  command -v nc >/dev/null 2>&1 && nc -z -G 1 127.0.0.1 "$1" >/dev/null 2>&1 && return 0
  return 1
}

choose_port() {
  PORT=$(marker_get port)
  if [ -n "$PORT" ] && { [ -z "${DROPPEN_PORT:-}" ] || [ "$DROPPEN_PORT" = "$PORT" ]; }; then
    return 0 # keep the address the browser already knows
  fi
  first=${DROPPEN_PORT:-8700}
  case "$first" in ''|*[!0-9]*) die "DROPPEN_PORT must be a number" ;; esac
  PORT=$first
  while port_busy "$PORT"; do
    PORT=$((PORT + 1))
    [ "$PORT" -lt $((first + 50)) ] || die "no free port between $first and $PORT"
  done
}

install_binary() {
  mkdir -p "$BIN_DIR"
  if [ -f "$BIN" ] && cmp -s "$NEW" "$BIN"; then
    BINARY_CHANGED=0
    say "Already installed: $NEW_VERSION"
    return 0
  fi
  BINARY_CHANGED=1
  OLD_VERSION=""
  if [ -f "$BIN" ]; then
    OLD_VERSION=$("$BIN" --version 2>/dev/null || echo unknown)
    # Keep the one being replaced as .prev, the supervisor's rollback.
    cp -p "$BIN" "$BIN_DIR/.staging-install-prev"
    mv -f "$BIN_DIR/.staging-install-prev" "$BIN.prev"
  fi
  # Copy beside it, then rename: the installed path is never half written.
  cp "$NEW" "$BIN_DIR/.staging-install"
  chmod 755 "$BIN_DIR/.staging-install"
  mv -f "$BIN_DIR/.staging-install" "$BIN"
  if [ -n "$OLD_VERSION" ]; then
    say "Upgraded $OLD_VERSION -> $NEW_VERSION"
  else
    say "Installed $NEW_VERSION to $BIN"
  fi
}

default_user() {
  name=${DROPPEN_USER:-}
  [ -n "$name" ] || name=$(id -un | LC_ALL=C tr '[:upper:]' '[:lower:]')
  if printf '%s\n' "$name" | grep -Eq '^[a-z0-9._-]{1,32}$'; then
    printf '%s\n' "$name"
  elif [ -n "${DROPPEN_USER:-}" ]; then
    die "DROPPEN_USER must be 1-32 characters of a-z, 0-9, '.', '_' or '-'"
  else
    printf 'droppen\n'
  fi
}

# The local page has its own login (accounts of this server, kept in its
# instance). With no account the server answers anyone who reaches its port, so
# the first one is made before the server is ever started.
ensure_account() {
  step "Local login"
  listing=$(run_bin user list --instance "$INSTANCE") || die "could not read this server's accounts"
  case "$listing" in
    "no accounts"*) ;;
    *)
      USERS=$(printf '%s\n' "$listing" | sed 1d | cut -f1 | tr '\n' ' ' | sed 's/ $//')
      say "Sign in with your existing account: $USERS"
      ACCOUNT_NOTE="your existing account ($USERS)"
      return 0 ;;
  esac
  USER_NAME=$(default_user)
  if (: </dev/tty) 2>/dev/null; then
    say "Choose a password for the Droppen page on this Mac (user: $USER_NAME, at least 12 characters)."
    say "为这台 Mac 上的 Droppen 本地页面设置密码（用户名 ${USER_NAME}，至少 12 个字符）。"
    tries=0
    until run_bin user add "$USER_NAME" --instance "$INSTANCE" </dev/tty; do
      tries=$((tries + 1))
      [ "$tries" -lt 3 ] || die "no account was created, so Droppen was not started (it would be open to anyone who can reach it). Run the installer again."
      say "Try again. / 请重试。"
    done
    ACCOUNT_NOTE="$USER_NAME, with the password you just chose"
  else
    # No terminal (an unattended run): generate one and show it once.
    password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
    [ "${#password}" -eq 24 ] || die "could not generate a password"
    printf '%s\n' "$password" | run_bin user add "$USER_NAME" --instance "$INSTANCE" >/dev/null \
      || die "could not create the first account; Droppen was not started"
    say "No terminal to ask for a password on, so one was generated. It is shown only this once:"
    say ""
    say "    user:     $USER_NAME"
    say "    password: $password"
    say ""
    say "Change it later with: $BIN user passwd $USER_NAME --instance $INSTANCE"
    ACCOUNT_NOTE="$USER_NAME, with the generated password above"
  fi
}

xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

service_path() {
  if [ -n "${DROPPEN_SERVICE_PATH:-}" ]; then
    printf '%s\n' "$DROPPEN_SERVICE_PATH"
    return 0
  fi
  # A launchd agent does not read your shell profile: without this, `claude`,
  # `codex`, `node` and `git` would be missing from every session it starts.
  path="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  old_ifs=$IFS
  IFS=:
  set -f
  for dir in ${PATH:-}; do
    case "$dir" in
      /*) ;;
      *) continue ;;
    esac
    case ":$path:" in *":$dir:"*) continue ;; esac
    case "$dir" in */remote-hand/instances/*) continue ;; esac # a session's own bin dir
    [ -d "$dir" ] && path="$path:$dir"
  done
  set +f
  IFS=$old_ifs
  printf '%s\n' "$path"
}

write_plist() {
  mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
  cat > "$TMP/agent.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Droppen server, written by $(xml "$INSTALL_CMD"). Rerun it to upgrade. -->
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$(xml "$LABEL")</string>
    <!-- The supervisor: restarts into self-updates, rolls back a binary that will not stay up. -->
    <key>ProgramArguments</key>
    <array>
        <string>$(xml "$BIN")</string>
        <string>up</string>
        <string>--</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <!-- Terminals and agent runs outlive a server restart; launchd must not kill them with it. -->
    <key>AbandonProcessGroup</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$(xml "$HOME")</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$(xml "$HOME")</string>
        <!-- Loopback only. Reach it from elsewhere through Droppen, an SSH tunnel or Tailscale. -->
        <key>APP_SERVER__HOST</key>
        <string>127.0.0.1</string>
        <key>APP_SERVER__PORT</key>
        <string>$PORT</string>
        <key>APP_INSTANCE</key>
        <string>$INSTANCE</string>
        <key>LANG</key>
        <string>$(xml "${LANG:-en_US.UTF-8}")</string>
        <key>PATH</key>
        <string>$(xml "$(service_path)")</string>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$(xml "$LOG_DIR/$INSTANCE.log")</string>
    <key>StandardErrorPath</key>
    <string>$(xml "$LOG_DIR/$INSTANCE.err.log")</string>
</dict>
</plist>
EOF
  plutil -lint "$TMP/agent.plist" >/dev/null || die "the launchd agent file did not come out valid"
  if [ -f "$PLIST" ] && cmp -s "$TMP/agent.plist" "$PLIST"; then
    PLIST_CHANGED=0
  else
    PLIST_CHANGED=1
    cp "$TMP/agent.plist" "$PLIST"
  fi
}

# Written before anything is installed, so a run that stops halfway (a
# password refused three times, a closed terminal) is still recognised as ours.
write_marker() {
  mkdir -p "$CONFIG_DIR"
  cat > "$MARKER" <<EOF
# Written by the Droppen installer ($RELEASES_URL), which reads it to
# recognise its own install. Deleting it makes the installer treat the server
# below as somebody else's.
label=$LABEL
instance=$INSTANCE
port=$PORT
version=$VERSION
EOF
}

wait_gone() {
  i=0
  while loaded; do
    i=$((i + 1))
    [ "$i" -lt 100 ] || die "launchd did not stop $LABEL"
    sleep 0.1
  done
}

start_service() {
  launchctl enable "$DOMAIN/$LABEL" 2>/dev/null || true
  if loaded; then
    if [ "$PLIST_CHANGED" = 1 ]; then
      launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
      wait_gone
      launchctl bootstrap "$DOMAIN" "$PLIST" || die "launchctl bootstrap failed for $PLIST"
      launchctl kickstart "$DOMAIN/$LABEL" 2>/dev/null || true
      say "Restarted $LABEL with its new settings"
    elif [ "$BINARY_CHANGED" = 1 ]; then
      launchctl kickstart -k "$DOMAIN/$LABEL" || die "launchctl kickstart failed for $LABEL"
      say "Restarted $LABEL"
    else
      launchctl kickstart "$DOMAIN/$LABEL" 2>/dev/null || true
      say "$LABEL is running"
    fi
  else
    launchctl bootstrap "$DOMAIN" "$PLIST" || die "launchctl bootstrap failed for $PLIST"
    # RunAtLoad may be held back as a "speculative" spawn on a busy Mac: start it now.
    launchctl kickstart "$DOMAIN/$LABEL" 2>/dev/null || true
    say "Started $LABEL (starts at login, restarts if it stops)"
  fi
}

wait_healthy() {
  step "Waiting for Droppen on $URL"
  i=0
  status=""
  while [ "$i" -lt 120 ]; do
    status=$(curl -fsS -m 2 "$URL/api/auth/status" 2>/dev/null) && break
    status=""
    i=$((i + 1))
    sleep 0.5
  done
  if [ -z "$status" ]; then
    say "The last lines of $LOG_DIR/$INSTANCE.err.log:"
    tail -n 20 "$LOG_DIR/$INSTANCE.err.log" 2>/dev/null || true
    die "Droppen did not answer on $URL within a minute"
  fi
  case "$status" in
    *'"authRequired":true'*) say "Healthy, and the page asks for a login" ;;
    *)
      # Never leave it open: stop it rather than serve anyone who can reach the port.
      launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
      die "the server answered without requiring a login, so it was stopped ($status)" ;;
  esac
}

install() {
  check_platform
  find_others
  [ -z "$CONFLICT" ] || refuse_conflict
  resolve_version
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/droppen-install.XXXXXX")
  trap 'rm -rf "$TMP"' EXIT
  trap 'exit 130' INT TERM
  download_and_verify
  choose_port
  URL=http://127.0.0.1:$PORT
  step "Installing"
  write_marker
  install_binary
  ensure_account
  step "Starting the server"
  write_plist
  start_service
  wait_healthy
  if [ "${DROPPEN_NO_OPEN:-}" != 1 ]; then
    open "$URL/" >/dev/null 2>&1 || true
  fi
  report_others
  cat <<EOF

Droppen $VERSION is running at $URL
Droppen $VERSION 已在 $URL 运行

  Sign in:    $ACCOUNT_NOTE
  Next:       choose 「登录 Droppen」 on that page to connect this Mac to your Droppen account
  Service:    launchd $LABEL, starts at login, port $PORT
  Data:       $DATA_DIR (instance $INSTANCE), $CONFIG_DIR
  Logs:       $LOG_DIR/$INSTANCE.log
  Upgrade:    $INSTALL_CMD
  Uninstall:  $INSTALL_CMD -s -- --uninstall

This is the server, for background and headless use. For everyday use, the
Droppen desktop App is recommended: $RELEASES_URL/releases/latest
这是后台/无界面使用的服务端；日常使用推荐 Droppen 桌面 App（同一发布页）。
EOF
}

# ---------------------------------------------------------------- uninstall

uninstall() {
  check_platform
  find_others
  if ! ours && [ ! -f "$PLIST" ]; then
    report_others
    say ""
    say "Droppen is not installed by this installer for this user (no $LABEL); nothing to do."
    exit 0
  fi
  step "Uninstalling $LABEL"
  if loaded; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    wait_gone
    say "Stopped $LABEL"
  fi
  rm -f "$PLIST"
  if [ -n "$CONFLICT" ] && [ -e "$BIN" ]; then
    say "Kept $BIN: $CONFLICT."
  else
    rm -f "$BIN" "$BIN.prev" "$BIN.bad" "$BIN_DIR"/.staging-*
    rmdir "$BIN_DIR" 2>/dev/null || true
    say "Removed $BIN"
  fi
  report_others
  cat <<EOF

Droppen is uninstalled. Your data was kept, so installing again picks it up:
Droppen 已卸载；数据已保留，重新安装即可继续使用：
    $DATA_DIR
    $CONFIG_DIR
    $LOG_DIR
To delete it as well (sessions, accounts, settings), run:
    rm -rf "$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR"
EOF
}

main() {
  action=install
  for arg in "$@"; do
    case "$arg" in
      --uninstall) action=uninstall ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $arg" ;;
    esac
  done
  set_paths
  "$action"
}

# Everything above only defines functions, so a download cut short runs nothing.
main "$@"
