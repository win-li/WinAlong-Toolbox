# 架构说明

WinAlong Toolbox 采用小型、可组合的 Bash 模块架构。

- `toolbox.sh`：程序入口，仅加载配置、公共库和模块，并负责主菜单调度。
- `lib/common.sh`：权限、交互确认、系统识别与日志等公共能力。
- `lib/ui.sh`：统一的标题、菜单和消息输出。
- `modules/system.sh`：系统信息、BBR、Swap 状态与系统管理菜单。
- `modules/packages.sh`：Ubuntu/Debian 软件包更新检查与安装。
- `modules/time.sh`：systemd 时间同步状态与启用操作。
- `modules/swap.sh`：带输入验证、重复检测和失败清理的 Swap 创建。
- `modules/docker.sh`：Docker 官方仓库安装、服务控制与只读资源查询。
- `modules/portainer.sh`：本机绑定的 Portainer CE LTS 部署、状态、日志和生命周期管理。
- `modules/apps.sh`：基于安全目录配置的 Docker 应用部署与生命周期管理。
- `modules/backup.sh`：应用网络接入、数据卷一致性备份、校验、恢复与回滚。
- `modules/security.sh`：只读安全审计、UFW 安全启用和 Fail2ban SSH 防护。
- `config/apps.conf`：应用镜像、容器、数据卷和本机端口的默认目录。
- `config/default.conf`：可提交的默认配置；本地覆盖使用 `config/local.conf`。
- `tests/smoke.sh`：关键文件、Bash 语法、ShellCheck 与模块静态测试入口。
- `tests/docker_static.sh`：验证 Docker 公共函数及禁止数据删除操作。
- `tests/portainer_static.sh`：验证 Portainer 不公开管理端口、不启用 Edge 端口且不删除数据。
- `tests/apps_static.sh`：验证应用目录只绑定回环地址、不使用 host 网络且不删除数据。
- `tests/backup_static.sh`：验证恢复确认、挂载点清理范围及禁止删除 Docker 数据卷。
- `tests/security_static.sh`：验证不修改 SSH、不重置防火墙、不硬编码开放端口及强确认短语。

## 设计原则

1. 主入口不承载具体系统操作。
2. 默认功能应可重复执行，并优先采用只读检查。
3. 任何会修改系统状态的功能必须明确提示并单独实现。
4. 运行日志与备份位于安装目录之外，卸载时默认保留。
5. 当前支持目标为 Ubuntu 22.04、Ubuntu 24.04 和 Debian 12。
6. 系统写操作必须要求 root 权限、明确确认并写入日志。
7. Docker 模块不删除容器、镜像或数据卷，不开放端口，也不授予用户 Docker 特权。
8. Portainer 管理端口默认仅绑定回环地址，远程访问使用 SSH 隧道。
9. 应用模板必须使用明确镜像、命名数据卷和回环地址绑定；高风险网络应用单独评审。
10. 恢复必须先校验归档并创建安全快照，数据清理只能发生在临时容器的 `/target` 卷挂载点。
11. 防火墙启用前必须先允许检测到的 SSH 端口；安全模块不得修改 SSH 登录配置。
