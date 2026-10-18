# Droppen

**English** · [简体中文](#简体中文)

Claude Code and Codex keep running on your own Mac; from your phone or any
browser you watch them work, answer their questions and open a terminal,
end-to-end encrypted.

This repository holds Droppen's **release binaries** and its install script,
nothing else. The source code will be published at
[github.com/getdroppen/droppen](https://github.com/getdroppen/droppen).

**For everyday use, install the Droppen desktop App**: `Droppen-<version>.dmg` on
the [Releases page](https://github.com/getdroppen/releases/releases/latest). The
installer below is the **server install**, for running Droppen in the
background, on a headless Mac or on a Linux machine.

## Install the server

macOS 11 or later (Apple silicon or Intel), or Linux on x86_64 or aarch64 with
glibc 2.28 or newer (Debian 10, Ubuntu 20.04, RHEL 8 and later). Run it as the
user Droppen should run as: no `sudo`, and not as root.

```sh
curl -fsSL https://droppen.app/install.sh | sh
```

### On a headless machine: join your account with a code

On droppen.app, choose **Add a computer** to get a one-time code, then run:

```sh
curl -fsSL https://droppen.app/install.sh | DROPPEN_CODE=RH1-... sh
```

The installer joins this machine to your account and starts it; confirm the
machine on droppen.app while it waits (up to 10 minutes). No browser is needed
on the machine. `sh -s -- --code RH1-...` does the same, but other users of a
shared machine can see a command line while it runs; `DROPPEN_CODE` keeps the
code out of it.

`https://droppen.app/install.sh` is a redirect to [`install.sh`](install.sh) in
this repository, so you can read exactly what runs. It:

1. downloads the latest [release](https://github.com/getdroppen/releases/releases/latest)
   for your machine and checks its SHA-256 against the release's `SHA256SUMS`;
2. installs the server to `~/.local/share/remote-hand/bin/remote-hand-server`;
3. creates the login for the local page: an account named after your user,
   with a password you choose (at least 12 characters). Run without a
   terminal, it generates a password and prints it once;
4. with a code, joins your Droppen account (`remote-hand-server agent enroll`);
5. runs the server as a service on `127.0.0.1:8700` or the next free port,
   restarted if it stops: a launchd user agent (`app.droppen.server`) on macOS,
   a systemd user service (`droppen.service`) on Linux;
6. waits until the server answers and asks for a login, then, on a Mac or a
   Linux desktop and without a code, opens `http://127.0.0.1:<port>`.

Without a code, sign in to that page with the account from step 3, then choose
**「登录 Droppen」** (Sign in to Droppen) to connect the machine to your account.

The server listens on `127.0.0.1` only and runs as you. The page never starts
without a password: if the server ever answers without asking for one, the
installer stops it.

### Linux

- The service is a **systemd user service**, `droppen.service`
  (`systemctl --user status droppen`; logs: `journalctl --user -u droppen`).
  A user service stops when you log out. To keep it running, and start it at
  boot: `sudo loginctl enable-linger $USER` (the installer reminds you).
- With no systemd user session (a container, another init system), the
  installer prints the exact command to start the server yourself.
- `curl -fsSL https://droppen.app/install.sh | sh -s -- --system` installs a
  system service instead, `droppen-<user>.service`, that starts at boot and
  runs as you; sudo is asked only to write the unit file.

### Upgrade

Run the same command again. It replaces the binary in place, keeps the previous
one as `remote-hand-server.prev`, and keeps your data, accounts and port.

### Options

Environment variables, for example
`curl -fsSL https://droppen.app/install.sh | DROPPEN_VERSION=v0.2.118 sh`:

| variable | |
|---|---|
| `DROPPEN_CODE=RH1-...` | join the account the one-time code is from |
| `DROPPEN_VERSION=v0.2.119` | install this release instead of the latest |
| `DROPPEN_PORT=8800` | the first port to try on a new install |
| `DROPPEN_USER=name` | the first account's name (`a-z`, `0-9`, `.`, `_`, `-`) |
| `DROPPEN_NO_OPEN=1` | do not open the browser |
| `DROPPEN_SERVICE_PATH=...` | the `PATH` the server, and the agents it starts, run with (default: common tool directories plus your current `PATH`) |

## Manual download

From the [latest release](https://github.com/getdroppen/releases/releases/latest),
download `SHA256SUMS` and the tarball for your machine:

| file | for |
|---|---|
| `remote-hand-<version>-macos-aarch64.tar.gz` | Apple silicon |
| `remote-hand-<version>-macos-x86_64.tar.gz` | Intel Mac |
| `remote-hand-<version>-macos-universal.tar.gz` | either Mac |
| `remote-hand-<version>-linux-x86_64.tar.gz` | Linux x86_64, glibc 2.28+ |
| `remote-hand-<version>-linux-aarch64.tar.gz` | Linux aarch64, glibc 2.28+ |

Check it (`sha256sum -c SHA256SUMS --ignore-missing` on Linux). On Linux, follow
`INSTALL.txt` in the tarball. On a Mac, install by hand:

```sh
shasum -a 256 -c SHA256SUMS --ignore-missing   # must print "<file>: OK"
tar -xzf remote-hand-*-macos-aarch64.tar.gz remote-hand-server
mkdir -p ~/.local/share/remote-hand/bin
mv remote-hand-server ~/.local/share/remote-hand/bin/
# Downloaded with a browser? Clear the quarantine flag:
xattr -d com.apple.quarantine ~/.local/share/remote-hand/bin/remote-hand-server
# The local login, before the first start (a lower-case name):
~/.local/share/remote-hand/bin/remote-hand-server user add "$(id -un)" --instance default
~/.local/share/remote-hand/bin/remote-hand-server up -- serve
```

Then open <http://127.0.0.1:8700>. `INSTALL.txt` in the tarball says more.

`SHA256SUMS` is published in the same release as the tarballs, so it catches a
corrupted or swapped download, not a compromised release.

## Uninstall

```sh
curl -fsSL https://droppen.app/install.sh | sh -s -- --uninstall
```

This stops and removes the launchd agent and the binary. Your data is kept, and
installing again picks it up. To delete it as well:

```sh
rm -rf ~/.local/share/remote-hand ~/.config/remote-hand ~/Library/Logs/remote-hand
```

On Linux, the logs live in `~/.local/state/remote-hand` instead of
`~/Library/Logs/remote-hand`. If the machine joined your Droppen account, remove
it on droppen.app too.

By hand, without the script:

```sh
# macOS
launchctl bootout gui/$(id -u)/app.droppen.server
rm ~/Library/LaunchAgents/app.droppen.server.plist ~/.local/share/remote-hand/bin/remote-hand-server*
# Linux
systemctl --user disable --now droppen
rm ~/.config/systemd/user/droppen.service ~/.local/share/remote-hand/bin/remote-hand-server*
```

## Where things are

| what | where |
|---|---|
| the server | `~/.local/share/remote-hand/bin/remote-hand-server` (and `.prev`） |
| its data: sessions, terminals, the local accounts | `~/.local/share/remote-hand/instances/default/` |
| settings | `~/.config/remote-hand/` |
| the launchd agent (macOS) | `~/Library/LaunchAgents/app.droppen.server.plist` |
| the systemd unit (Linux) | `~/.config/systemd/user/droppen.service`, or `/etc/systemd/system/droppen-<user>.service` with `--system` |
| this machine's key, once it joined an account | `~/.local/share/remote-hand/instances/default/agent/` |
| logs | macOS: `~/Library/Logs/remote-hand/default.log`; Linux: the journal |

The binary and its directories still carry Droppen's former name,
`remote-hand`; they will be renamed when the source is published. The installer
runs the server's `default` instance. If you already run Droppen (remote-hand)
servers of your own, it lists them and leaves them alone, and it will not
install over a server it did not install.

The local page's accounts are this server's own, separate from your Droppen
account:
`~/.local/share/remote-hand/bin/remote-hand-server user list|add|passwd|rm <name> --instance default`.

## License

Droppen is licensed under the GNU Affero General Public License v3.0 only
(AGPL-3.0-only); see [LICENSE](LICENSE). Copyright © 2026 droppen.app.

Every release includes `THIRD_PARTY_NOTICES`: the third-party software in the
server, with its licenses.

The source code will be published at
[github.com/getdroppen/droppen](https://github.com/getdroppen/droppen). Until
then, the source of any release is available on request:
[open an issue](https://github.com/getdroppen/releases/issues/new) naming the
version.

---

## 简体中文

Claude Code 和 Codex 照常在你自己的 Mac 上跑；在手机或任何浏览器上看它干活、回答它的提问、打开终端，全程端到端加密。

这个仓库只放 Droppen 的**发布二进制**和安装脚本。源代码将发布在
[github.com/getdroppen/droppen](https://github.com/getdroppen/droppen)。

**日常使用请安装 Droppen 桌面 App**：[发布页](https://github.com/getdroppen/releases/releases/latest)上的 `Droppen-<版本>.dmg`。下面的安装脚本是**服务端安装**，用于在后台、无界面的 Mac 或 Linux 机器上运行 Droppen。

### 安装服务端

macOS 11 及以上（Apple 芯片或 Intel），或 x86_64 / aarch64 的 Linux（glibc 2.28 及以上：Debian 10、Ubuntu 20.04、RHEL 8 及更新）。用 Droppen 要运行的那个用户执行：不需要 `sudo`，也不要用 root。

```sh
curl -fsSL https://droppen.app/install.sh | sh
```

### 无界面机器：用一次性代码加入账号

在 droppen.app 上选择**添加电脑**拿到一次性代码，然后运行：

```sh
curl -fsSL https://droppen.app/install.sh | DROPPEN_CODE=RH1-... sh
```

安装脚本会把这台机器加入你的账号并启动服务；等待期间（最多 10 分钟）在 droppen.app 上确认这台机器即可，机器上不需要浏览器。`sh -s -- --code RH1-...` 效果相同，但在多人共用的机器上，运行期间其他用户能看到命令行；`DROPPEN_CODE` 不会把代码放进命令行。

`https://droppen.app/install.sh` 会重定向到本仓库的 [`install.sh`](install.sh)，运行的内容都可以在这里看到。它会：

1. 下载适合这台机器的最新[版本](https://github.com/getdroppen/releases/releases/latest)，并用该版本的 `SHA256SUMS` 校验 SHA-256；
2. 把服务端装到 `~/.local/share/remote-hand/bin/remote-hand-server`；
3. 为本地页面创建登录账号：用户名取你的用户名，密码由你设置（至少 12 个字符）。没有终端可交互时，会生成一个密码并只显示这一次；
4. 带代码时，加入你的 Droppen 账号（`remote-hand-server agent enroll`）；
5. 把服务端作为服务运行在 `127.0.0.1:8700`（被占用则用下一个空闲端口），退出后自动拉起：macOS 上是 launchd 用户代理（`app.droppen.server`），Linux 上是 systemd 用户服务（`droppen.service`）；
6. 等服务端就绪并确认它要求登录后，在 Mac 或 Linux 桌面上、且没有代码时，打开 `http://127.0.0.1:<端口>`。

没有代码时，用第 3 步的账号登录该页面，然后点 **「登录 Droppen」**，把这台机器接入你的账号。

服务端只监听 `127.0.0.1`，以你的用户身份运行。本地页面不会在没有密码的情况下启动：如果服务端不要求登录，安装脚本会把它停掉。

### Linux

- 服务是 **systemd 用户服务** `droppen.service`（`systemctl --user status droppen`；日志：`journalctl --user -u droppen`）。用户服务会在你登出后停止；要让它持续运行并开机启动：`sudo loginctl enable-linger $USER`（安装脚本会提醒）。
- 没有 systemd 用户会话时（容器、其他 init 系统），安装脚本会打印手动启动服务端的完整命令。
- `curl -fsSL https://droppen.app/install.sh | sh -s -- --system` 改为安装系统服务 `droppen-<用户名>.service`：开机启动、以你的身份运行；只在写入服务文件时请求 sudo。

### 升级

再运行一次同一条命令即可：原地替换二进制，旧版本保留为 `remote-hand-server.prev`，数据、账号和端口都不变。

### 选项

通过环境变量设置，例如 `curl -fsSL https://droppen.app/install.sh | DROPPEN_VERSION=v0.2.118 sh`：

| 变量 | |
|---|---|
| `DROPPEN_CODE=RH1-...` | 加入该一次性代码所属的账号 |
| `DROPPEN_VERSION=v0.2.119` | 安装指定版本，而不是最新版 |
| `DROPPEN_PORT=8800` | 新安装时首先尝试的端口 |
| `DROPPEN_USER=name` | 第一个账号的用户名（`a-z`、`0-9`、`.`、`_`、`-`） |
| `DROPPEN_NO_OPEN=1` | 不打开浏览器 |
| `DROPPEN_SERVICE_PATH=...` | 服务端及其启动的 agent 使用的 `PATH`（默认：常见工具目录加上你当前的 `PATH`） |

### 手动下载

从[最新版本](https://github.com/getdroppen/releases/releases/latest)下载 `SHA256SUMS` 和适合你的压缩包：

| 文件 | 适用 |
|---|---|
| `remote-hand-<版本>-macos-aarch64.tar.gz` | Apple 芯片 |
| `remote-hand-<版本>-macos-x86_64.tar.gz` | Intel Mac |
| `remote-hand-<版本>-macos-universal.tar.gz` | 两种 Mac 皆可 |
| `remote-hand-<版本>-linux-x86_64.tar.gz` | Linux x86_64，glibc 2.28+ |
| `remote-hand-<版本>-linux-aarch64.tar.gz` | Linux aarch64，glibc 2.28+ |

先校验（Linux 上用 `sha256sum -c SHA256SUMS --ignore-missing`）。Linux 请按压缩包里的 `INSTALL.txt` 操作；Mac 上手动安装：

```sh
shasum -a 256 -c SHA256SUMS --ignore-missing   # 必须输出 "<文件>: OK"
tar -xzf remote-hand-*-macos-aarch64.tar.gz remote-hand-server
mkdir -p ~/.local/share/remote-hand/bin
mv remote-hand-server ~/.local/share/remote-hand/bin/
# 用浏览器下载的，先清除隔离标记：
xattr -d com.apple.quarantine ~/.local/share/remote-hand/bin/remote-hand-server
# 首次启动前创建本地登录账号（用户名须为小写）：
~/.local/share/remote-hand/bin/remote-hand-server user add "$(id -un)" --instance default
~/.local/share/remote-hand/bin/remote-hand-server up -- serve
```

然后打开 <http://127.0.0.1:8700>。压缩包里的 `INSTALL.txt` 有更多说明。

`SHA256SUMS` 与压缩包发布在同一个版本里，所以它能发现下载损坏或被替换，但防不住整个版本被篡改。

### 卸载

```sh
curl -fsSL https://droppen.app/install.sh | sh -s -- --uninstall
```

会停止并删除 launchd 代理和二进制。数据会保留，重新安装即可继续使用。如果要一并删除：

```sh
rm -rf ~/.local/share/remote-hand ~/.config/remote-hand ~/Library/Logs/remote-hand
```

Linux 上日志在 `~/.local/state/remote-hand`，而不是 `~/Library/Logs/remote-hand`。如果这台机器加入过你的 Droppen 账号，也请在 droppen.app 上把它移除。

不用脚本、手动卸载：

```sh
# macOS
launchctl bootout gui/$(id -u)/app.droppen.server
rm ~/Library/LaunchAgents/app.droppen.server.plist ~/.local/share/remote-hand/bin/remote-hand-server*
# Linux
systemctl --user disable --now droppen
rm ~/.config/systemd/user/droppen.service ~/.local/share/remote-hand/bin/remote-hand-server*
```

### 文件位置

| 内容 | 位置 |
|---|---|
| 服务端 | `~/.local/share/remote-hand/bin/remote-hand-server`（以及 `.prev`） |
| 数据：会话、终端、本地账号 | `~/.local/share/remote-hand/instances/default/` |
| 设置 | `~/.config/remote-hand/` |
| launchd 代理（macOS） | `~/Library/LaunchAgents/app.droppen.server.plist` |
| systemd 单元（Linux） | `~/.config/systemd/user/droppen.service`；`--system` 时为 `/etc/systemd/system/droppen-<用户名>.service` |
| 加入账号后这台机器的密钥 | `~/.local/share/remote-hand/instances/default/agent/` |
| 日志 | macOS：`~/Library/Logs/remote-hand/default.log`；Linux：journal |

二进制和目录仍沿用 Droppen 的旧名 `remote-hand`，源代码公开时会一并改名。安装脚本使用服务端的 `default` 实例。如果你自己已经在运行 Droppen（remote-hand）服务端，脚本会列出它们、不做任何改动，也不会覆盖不是它安装的服务端。

本地页面的账号属于这台服务端，与你的 Droppen 账号无关：
`~/.local/share/remote-hand/bin/remote-hand-server user list|add|passwd|rm <用户名> --instance default`。

### 许可证

Droppen 以 GNU Affero General Public License v3.0 only（AGPL-3.0-only）授权，见 [LICENSE](LICENSE)。Copyright © 2026 droppen.app。

每个版本都附带 `THIRD_PARTY_NOTICES`，列出服务端包含的第三方软件及其许可证。

源代码将发布在 [github.com/getdroppen/droppen](https://github.com/getdroppen/droppen)。在那之前，任何版本的源代码都可以索取：[提一个 issue](https://github.com/getdroppen/releases/issues/new)，写明版本号。
