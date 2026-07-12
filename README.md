# WinAlong Toolbox

WinAlong Toolbox 是面向 Linux VPS 用户的中文命令行服务器工具箱。本项目当前专注于清晰、可维护的项目骨架和低风险的只读检查。

## v0.3.0 功能

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

所有系统写操作都要求 root 权限并二次确认。Docker 模块不会开放端口、创建应用容器、删除数据或自动将用户加入 `docker` 用户组。项目仍处于早期开发阶段（v0.3.0），请先在测试 VPS 验证，再用于重要环境。架构说明见 `docs/architecture.md`。
