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
background or on a headless Mac.

## Install the server

macOS 11 or later, Apple silicon or Intel. No `sudo`.

```sh
curl -fsSL https://droppen.app/install.sh | sh
```

`https://droppen.app/install.sh` is a redirect to [`install.sh`](install.sh) in
this repository, so you can read exactly what runs. It:

1. downloads the latest [release](https://github.com/getdroppen/releases/releases/latest)
   for your Mac and checks its SHA-256 against the release's `SHA256SUMS`;
2. installs the server to `~/.local/share/remote-hand/bin/remote-hand-server`;
3. creates the login for the local page: an account named after your macOS
   user, with a password you choose (at least 12 characters). Run without a
   terminal, it generates a password and prints it once;
4. registers a launchd user agent, `app.droppen.server`, that starts the server
   at login and restarts it if it stops, on `127.0.0.1:8700` or the next free
   port;
5. waits until the server answers and asks for a login, then opens
   `http://127.0.0.1:<port>` in your browser.

Sign in there with the account from step 3, then choose **「登录 Droppen」**
(Sign in to Droppen) to connect this Mac to your Droppen account.

The server listens on `127.0.0.1` only and runs as you. The page never starts
without a password: if the server ever answers without asking for one, the
installer stops it.

**Linux** is coming soon. For now the installer says so and stops.

### Upgrade

Run the same command again. It replaces the binary in place, keeps the previous
one as `remote-hand-server.prev`, and keeps your data, accounts and port.

### Options

Environment variables, for example
`curl -fsSL https://droppen.app/install.sh | DROPPEN_VERSION=v0.2.118 sh`:

| variable | |
|---|---|
| `DROPPEN_VERSION=v0.2.118` | install this release instead of the latest |
| `DROPPEN_PORT=8800` | the first port to try on a new install |
| `DROPPEN_USER=name` | the first account's name (`a-z`, `0-9`, `.`, `_`, `-`) |
| `DROPPEN_NO_OPEN=1` | do not open the browser |
| `DROPPEN_SERVICE_PATH=...` | the `PATH` the server, and the agents it starts, run with (default: common tool directories plus your current `PATH`) |

## Manual download

From the [latest release](https://github.com/getdroppen/releases/releases/latest),
download `SHA256SUMS` and the tarball for your Mac:

| file | for |
|---|---|
| `remote-hand-<version>-macos-aarch64.tar.gz` | Apple silicon |
| `remote-hand-<version>-macos-x86_64.tar.gz` | Intel |
| `remote-hand-<version>-macos-universal.tar.gz` | either |

Check it, then install by hand:

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

By hand, without the script:

```sh
launchctl bootout gui/$(id -u)/app.droppen.server
rm ~/Library/LaunchAgents/app.droppen.server.plist ~/.local/share/remote-hand/bin/remote-hand-server*
```

## Where things are

| what | where |
|---|---|
| the server | `~/.local/share/remote-hand/bin/remote-hand-server` (and `.prev`） |
| its data: sessions, terminals, the local accounts | `~/.local/share/remote-hand/instances/default/` |
| settings | `~/.config/remote-hand/` |
| the launchd agent | `~/Library/LaunchAgents/app.droppen.server.plist` |
| logs | `~/Library/Logs/remote-hand/default.log`, `default.err.log` |

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
(AGPL-3.0-only); see [LICENSE](LICENSE). Copyright © 2026 Kilerd.

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

**日常使用请安装 Droppen 桌面 App**：[发布页](https://github.com/getdroppen/releases/releases/latest)上的 `Droppen-<版本>.dmg`。下面的安装脚本是**服务端安装**，用于在后台或无界面的 Mac 上运行 Droppen。

### 安装服务端

macOS 11 及以上，Apple 芯片或 Intel 均可，不需要 `sudo`。

```sh
curl -fsSL https://droppen.app/install.sh | sh
```

`https://droppen.app/install.sh` 会重定向到本仓库的 [`install.sh`](install.sh)，运行的内容都可以在这里看到。它会：

1. 下载适合你这台 Mac 的最新[版本](https://github.com/getdroppen/releases/releases/latest)，并用该版本的 `SHA256SUMS` 校验 SHA-256；
2. 把服务端装到 `~/.local/share/remote-hand/bin/remote-hand-server`；
3. 为本地页面创建登录账号：用户名取你的 macOS 用户名，密码由你设置（至少 12 个字符）。没有终端可交互时，会生成一个密码并只显示这一次；
4. 注册 launchd 用户代理 `app.droppen.server`：登录时自动启动，退出后自动拉起，监听 `127.0.0.1:8700`，被占用则用下一个空闲端口；
5. 等服务端就绪并确认它要求登录后，在浏览器中打开 `http://127.0.0.1:<端口>`。

用第 3 步的账号登录，然后点 **「登录 Droppen」**，把这台 Mac 接入你的 Droppen 账号。

服务端只监听 `127.0.0.1`，以你的用户身份运行。本地页面不会在没有密码的情况下启动：如果服务端不要求登录，安装脚本会把它停掉。

**Linux** 版即将推出，目前安装脚本会提示后退出。

### 升级

再运行一次同一条命令即可：原地替换二进制，旧版本保留为 `remote-hand-server.prev`，数据、账号和端口都不变。

### 选项

通过环境变量设置，例如 `curl -fsSL https://droppen.app/install.sh | DROPPEN_VERSION=v0.2.118 sh`：

| 变量 | |
|---|---|
| `DROPPEN_VERSION=v0.2.118` | 安装指定版本，而不是最新版 |
| `DROPPEN_PORT=8800` | 新安装时首先尝试的端口 |
| `DROPPEN_USER=name` | 第一个账号的用户名（`a-z`、`0-9`、`.`、`_`、`-`） |
| `DROPPEN_NO_OPEN=1` | 不打开浏览器 |
| `DROPPEN_SERVICE_PATH=...` | 服务端及其启动的 agent 使用的 `PATH`（默认：常见工具目录加上你当前的 `PATH`） |

### 手动下载

从[最新版本](https://github.com/getdroppen/releases/releases/latest)下载 `SHA256SUMS` 和适合你的压缩包：

| 文件 | 适用 |
|---|---|
| `remote-hand-<版本>-macos-aarch64.tar.gz` | Apple 芯片 |
| `remote-hand-<版本>-macos-x86_64.tar.gz` | Intel |
| `remote-hand-<版本>-macos-universal.tar.gz` | 两者皆可 |

校验后手动安装：

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

不用脚本、手动卸载：

```sh
launchctl bootout gui/$(id -u)/app.droppen.server
rm ~/Library/LaunchAgents/app.droppen.server.plist ~/.local/share/remote-hand/bin/remote-hand-server*
```

### 文件位置

| 内容 | 位置 |
|---|---|
| 服务端 | `~/.local/share/remote-hand/bin/remote-hand-server`（以及 `.prev`） |
| 数据：会话、终端、本地账号 | `~/.local/share/remote-hand/instances/default/` |
| 设置 | `~/.config/remote-hand/` |
| launchd 代理 | `~/Library/LaunchAgents/app.droppen.server.plist` |
| 日志 | `~/Library/Logs/remote-hand/default.log`、`default.err.log` |

二进制和目录仍沿用 Droppen 的旧名 `remote-hand`，源代码公开时会一并改名。安装脚本使用服务端的 `default` 实例。如果你自己已经在运行 Droppen（remote-hand）服务端，脚本会列出它们、不做任何改动，也不会覆盖不是它安装的服务端。

本地页面的账号属于这台服务端，与你的 Droppen 账号无关：
`~/.local/share/remote-hand/bin/remote-hand-server user list|add|passwd|rm <用户名> --instance default`。

### 许可证

Droppen 以 GNU Affero General Public License v3.0 only（AGPL-3.0-only）授权，见 [LICENSE](LICENSE)。Copyright © 2026 Kilerd。

每个版本都附带 `THIRD_PARTY_NOTICES`，列出服务端包含的第三方软件及其许可证。

源代码将发布在 [github.com/getdroppen/droppen](https://github.com/getdroppen/droppen)。在那之前，任何版本的源代码都可以索取：[提一个 issue](https://github.com/getdroppen/releases/issues/new)，写明版本号。
