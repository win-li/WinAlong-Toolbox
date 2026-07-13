# WinAlong Toolbox

WinAlong Toolbox 是面向 Linux VPS 用户的中文命令行服务器工具箱。本项目当前专注于清晰、可维护的项目骨架和低风险的只读检查。

## v1.3.0 功能

- 循环主菜单与可返回的系统检查子菜单
- 查看系统、内核、架构、内存和根分区信息
- 查看 BBR 拥塞控制状态
- 查看 Swap 状态
- 检查并安装 Ubuntu/Debian 常规软件包更新
- 查看并启用 systemd 时间同步
- 创建可配置大小的 Swap 文件（默认 `/swapfile`、`2G`）
- 查看 Docker 状态、版本、容器、镜像和磁盘占用
- 通过 Docker 官方 APT 仓库安装 Docker Engine 与 Compose 插件
- 经二次确认启动、停止或重启 Docker 服务
- 安全部署与管理 Portainer CE LTS
- Portainer 默认仅绑定 `127.0.0.1:9443`，通过 SSH 隧道访问
- 查看 Compose 项目和 Portainer 状态、日志
- Docker 应用中心：安全部署 Nginx 与 Uptime Kuma
- 应用状态、启停、重启、日志和 SSH 隧道访问说明
- 应用专用 Docker bridge 网络及容器名 DNS
- Nginx、Uptime Kuma 数据卷一致性备份
- 最新备份校验、恢复前安全快照和失败自动回滚
- 安全体检、监听端口与 Docker 公开端口检查
- UFW 安装、SSH 端口保护和安全启用
- Fail2ban SSH 防护、配置校验、备份与回滚
- 网络接口、路由、DNS 与连通性诊断
- MTR/Traceroute 路由质量分析和限量下载测速
- BBR/fq 状态检查、持久配置、备份与失败回滚
- 基于 GitHub HTTPS 的匿名在线版本检查与安全更新
- 更新前完整烟雾测试、安装目录快照与失败回滚
- 受所有者、文件权限、校验和与强确认保护的插件中心
- 内置只读系统摘要示例插件与管理员插件目录
- VPS 百分制健康体检、分项状态与可操作建议
- `--doctor`、`--version`、`--help` 非交互命令行入口
- 正式版发布清单、支持范围和验证记录
- 更新后维护状态：暂缓软件包、重启要求、运行内核、最新已安装内核和失败服务
- 健康评分区分少量更新、暂缓更新及待重启状态
- `winalong --maintenance` 非交互只读维护检查
- 日志中心：限量查看 WinAlong、Nginx、Uptime Kuma 和 Portainer 日志
- 自动备份计划：固定 systemd Timer、执行状态和手动触发入口
- 脱敏诊断报告：不采集主机名、IP、MAC、环境变量、SSH 配置或原始应用日志
- `--report`、`--backup-run`、`--backup-schedule` 命令行入口
- 自动识别 Linux 发行版
- 统一消息输出与运行日志
- 安装、卸载和烟雾测试脚本

不包含 DD 重装、SSH 修改、代理、VPN、开放端口等高风险功能。

## 支持系统

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 12

其他 Linux 发行版可能可以运行，但尚未列入支持范围。

## 直接运行

```bash
chmod +x toolbox.sh install.sh uninstall.sh tests/smoke.sh
./toolbox.sh
```

非交互入口：

```bash
./toolbox.sh --version
./toolbox.sh --help
sudo ./toolbox.sh --doctor
sudo ./toolbox.sh --maintenance
sudo ./toolbox.sh --report
sudo ./toolbox.sh --backup-run
sudo ./toolbox.sh --backup-schedule
```

## 从 GitHub 安装

推荐先克隆、检查并测试源码：

```bash
git clone https://github.com/win-li/WinAlong-Toolbox.git
cd WinAlong-Toolbox
bash tests/smoke.sh
sudo bash install.sh
winalong
```

## 快速管道安装

公开仓库可使用：

```bash
curl -fsSL https://raw.githubusercontent.com/win-li/WinAlong-Toolbox/main/bootstrap.sh | sudo bash
```

该命令会直接信任 GitHub 当时返回的 `bootstrap.sh`。引导器只接受 GitHub HTTPS 仓库，会克隆到临时目录并在安装前运行完整烟雾测试。安全要求较高时请使用上面的克隆安装方式，并先审阅源码。

## 本地源码安装

```bash
sudo bash install.sh
winalong
```

只读检查可以直接运行 `winalong`。软件包更新、启用时间同步和创建 Swap 等写操作请使用 `sudo winalong`，并在菜单中再次确认。

默认安装到 `/opt/winalong-toolbox`，并创建 `/usr/local/bin/winalong` 软链接。运行日志写入 `/var/log/winalong-toolbox`；普通用户无法写入该目录时，会回退到用户状态目录。

## 卸载

```bash
sudo bash /opt/winalong-toolbox/uninstall.sh
```

卸载会删除程序目录和本项目创建的软链接，但默认保留 `/var/log/winalong-toolbox` 与 `/var/backups/winalong-toolbox`。

## 测试

```bash
./tests/smoke.sh
```

测试会检查关键文件和所有 Shell 脚本语法；系统安装了 ShellCheck 时也会执行静态检查。

## 开发状态

所有系统写操作都要求 root 权限并二次确认。Portainer 需要挂载 Docker socket，因此拥有较高的服务器管理权限；默认不公开管理端口，也不启用 Edge Agent 的 8000 端口。Docker、Portainer 和应用中心不会自动将用户加入 `docker` 用户组。恢复会覆盖指定应用的数据卷，因此额外要求输入 `RESTORE`，并自动创建恢复前快照。启用 UFW、BBR 或自动备份额外要求输入完整确认词。v1.3.0 延续正式版安全边界，仍应先在测试 VPS 验证，再用于重要环境。架构说明见 `docs/architecture.md`，日志与诊断说明见 `docs/diagnostics.md`，发布验收见 `docs/release.md`。

## 日志、诊断与自动备份

日志中心默认最多显示 100 行，只允许选择项目登记的 Nginx、Uptime Kuma 和 Portainer 容器，不提供日志清空或无限跟随功能。日志可能包含访问路径或应用数据，分享前仍需人工检查。

`sudo winalong --report` 会在 `/var/log/winalong-toolbox/reports/` 生成权限为 `600` 的诊断报告。报告只包含系统资源、维护、安全和服务状态摘要，不采集主机名、IP、MAC、环境变量、SSH 配置或原始应用日志。

`sudo winalong --backup-schedule` 管理每日自动备份。默认计划为每天 03:30，并使用 `Persistent=true` 和最多 10 分钟随机延迟。定时任务仅备份已经部署的 Nginx 与 Uptime Kuma，不自动删除历史备份。修改 `config/local.conf` 中的 `WAT_BACKUP_CALENDAR` 可以覆盖时间；启用前会使用 `systemd-analyze calendar` 验证。

## VPS 健康体检

健康体检对支持系统、根磁盘、可用内存、CPU 负载、时间同步、待更新软件包、UFW、Fail2ban 和 BBR 进行只读检查，并生成百分制评分与建议。Docker 运行状态单独展示，不安装 Docker 不会扣分。为准确读取防火墙和容器状态，建议使用：

```bash
sudo winalong --doctor
```

## 在线更新与插件

公开版本默认通过 GitHub HTTPS 匿名拉取更新，不要求用户配置 GitHub 账号或 SSH 密钥。私有 Fork 仍可在 `config/local.conf` 中覆盖 `WAT_UPDATE_REPO` 为 SSH 地址；此时会继续使用 `SUDO_USER` 对应用户的 Ed25519 密钥。

项目使用 [MIT License](LICENSE)。贡献规范见 [CONTRIBUTING.md](CONTRIBUTING.md)，安全问题请按 [SECURITY.md](SECURITY.md) 私密报告，公开发布检查见 [docs/public-release.md](docs/public-release.md)。

在线更新默认从 GitHub 公开仓库的 `main` 分支通过 HTTPS 匿名拉取。更新只允许写入 `/opt/winalong-toolbox`，发现降级版本时会拒绝执行；安装前必须输入完整 `UPDATE`。

内置插件位于 `/opt/winalong-toolbox/plugins`，管理员插件位于 `/etc/winalong-toolbox/plugins`。插件文件必须由 root 所有，且组和其他用户不可写。运行前会显示 SHA-256，并要求输入完整 `RUN`。插件拥有当前进程的全部权限，只应运行已经审核的代码。

## 网络诊断与 BBR

网络中心提供：

- IPv4/IPv6 地址、路由和 DNS 状态。
- 对固定安全目标的 Ping 与 DNS 测试。
- MTR 或 Traceroute 路由质量分析。
- Cloudflare 25 MB 限量下载测速。
- BBR、可用拥塞控制和默认 qdisc 状态。
- 独立 sysctl 文件的 BBR/fq 启用、旧文件备份与失败回滚。

测速会消耗流量，并向 Cloudflare 暴露服务器出口 IP。网络模块不执行远程脚本，也不修改路由表。启用 BBR 主要影响新建 TCP 连接。

## 安全中心

安全中心提供：

- SSH 有效端口、root 登录策略和密码认证策略的只读检查。
- 系统监听端口、待更新软件包和 Docker 公开端口检查。
- UFW 状态、安装及安全启用。
- Fail2ban SSH jail 状态、安装和保守默认配置。

工具箱不会修改 `/etc/ssh/sshd_config`，不会启用 root SSH 登录，也不提供任意端口开放入口。启用 UFW 后必须保留当前 SSH 会话，并立即在另一个终端验证新 SSH 连接。

## 应用网络与备份

应用专用网络默认为 `winalong_apps`。同网络中的 Uptime Kuma 可以使用 `http://winalong-nginx` 监控 Nginx，不需要公开 Nginx 端口。

应用备份默认保存到 `/var/backups/winalong-toolbox/apps`，使用 Alpine 官方镜像将命名数据卷打包为 `tar.gz`。备份期间对应应用会短暂停止。恢复最新备份时会：

1. 校验目标压缩包。
2. 自动创建恢复前安全快照。
3. 停止对应容器并恢复数据卷。
4. 失败时尝试自动回滚安全快照。

恢复操作不可随意测试，应只在确有恢复需求时执行。

## Docker 应用中心

v0.5.0 提供两个低风险模板：

- Nginx：`nginx:stable-alpine`，本机端口 `8080`，数据卷 `winalong_nginx_html`。
- Uptime Kuma：`louislam/uptime-kuma:2`，本机端口 `3001`，数据卷 `winalong_uptime_kuma_data`。

两个 Web 服务都仅绑定 `127.0.0.1`。远程访问需按菜单提示建立 SSH 隧道。应用中心不提供删除容器或数据卷功能。

## Portainer 安全访问

部署后在 Windows PowerShell 建立 SSH 隧道：

```powershell
ssh -L 9443:127.0.0.1:9443 ubuntu@服务器公网IP
```

保持该窗口运行，然后访问 `https://localhost:9443`。Portainer 默认使用自签名证书，首次访问时浏览器可能显示证书提醒。

首次管理员初始化需在 Portainer 启动后 5 分钟内完成。Setup token 可从 Portainer 容器日志中读取，但不得截图、提交到 Git 或发送给他人。
