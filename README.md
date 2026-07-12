# WinAlong Toolbox

WinAlong Toolbox 是面向 Linux VPS 用户的中文命令行服务器工具箱。本项目当前专注于清晰、可维护的项目骨架和低风险的只读检查。

## v0.6.0 功能

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

## 安装

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

所有系统写操作都要求 root 权限并二次确认。Portainer 需要挂载 Docker socket，因此拥有较高的服务器管理权限；默认不公开管理端口，也不启用 Edge Agent 的 8000 端口。Docker、Portainer 和应用中心不会自动将用户加入 `docker` 用户组。恢复会覆盖指定应用的数据卷，因此额外要求输入 `RESTORE`，并自动创建恢复前快照。项目仍处于早期开发阶段（v0.6.0），请先在测试 VPS 验证，再用于重要环境。架构说明见 `docs/architecture.md`。

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
