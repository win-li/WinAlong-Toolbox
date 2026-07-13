# 架构说明

WinAlong Toolbox 采用小型、可组合的 Bash 模块架构。

v1.2.0 新增 `bootstrap.sh` 作为可选的公开快速安装入口。它不包含业务逻辑，只负责校验 root 和依赖、通过 GitHub HTTPS 克隆临时副本、运行完整烟雾测试并调用 `install.sh`。在线更新仍由 `modules/update.sh` 独立处理，不执行远程管道脚本。

- `toolbox.sh`：程序入口，仅加载配置、公共库和模块，并负责主菜单调度。
- `lib/common.sh`：权限、交互确认、系统识别与日志等公共能力。
- `lib/ui.sh`：统一的标题、菜单和消息输出。
- `modules/system.sh`：系统信息、BBR、Swap 状态与系统管理菜单。
- `modules/packages.sh`：Ubuntu/Debian 软件包更新、暂缓项、重启要求与内核状态检查。
- `modules/time.sh`：systemd 时间同步状态与启用操作。
- `modules/swap.sh`：带输入验证、重复检测和失败清理的 Swap 创建。
- `modules/docker.sh`：Docker 官方仓库安装、服务控制与只读资源查询。
- `modules/portainer.sh`：本机绑定的 Portainer CE LTS 部署、状态、日志和生命周期管理。
- `modules/apps.sh`：基于安全目录配置的 Docker 应用部署与生命周期管理。
- `modules/backup.sh`：应用网络接入、数据卷一致性备份、校验、恢复与回滚。
- `modules/security.sh`：只读安全审计、UFW 安全启用和 Fail2ban SSH 防护。
- `modules/network.sh`：原生网络诊断、限量测速及带回滚的 BBR/fq 管理。
- `modules/update.sh`：默认通过 GitHub HTTPS 暂存远程版本，同时兼容私有 SSH 仓库覆盖，并执行测试、快照、安装和失败回滚。
- `modules/plugins.sh`：插件发现、权限校验、校验和展示、强确认与隔离执行。
- `modules/doctor.sh`：只读健康指标、百分制评分、运行状态与改进建议。
- `modules/logs.sh`：限量运行日志、错误摘要、白名单容器日志与诊断菜单。
- `modules/report.sh`：不读取敏感来源的 root 专用脱敏诊断报告。
- `modules/scheduler.sh`：固定 systemd 单元、日历校验和明确确认保护的自动备份计划。
- `plugins/`：随项目发布的已审核插件；管理员插件保存在安装目录之外。
- `config/update.conf`：更新仓库、分支、通道与管理员插件目录。
- `config/doctor.conf`：健康体检阈值，不包含系统写操作。
- `config/maintenance.conf`：备份日历、固定单元名、日志行数和报告目录。
- `config/apps.conf`：应用镜像、容器、数据卷和本机端口的默认目录。
- `config/default.conf`：可提交的默认配置；本地覆盖使用 `config/local.conf`。
- `tests/smoke.sh`：关键文件、Bash 语法、ShellCheck 与模块静态测试入口。
- `tests/docker_static.sh`：验证 Docker 公共函数及禁止数据删除操作。
- `tests/portainer_static.sh`：验证 Portainer 不公开管理端口、不启用 Edge 端口且不删除数据。
- `tests/apps_static.sh`：验证应用目录只绑定回环地址、不使用 host 网络且不删除数据。
- `tests/backup_static.sh`：验证恢复确认、挂载点清理范围及禁止删除 Docker 数据卷。
- `tests/security_static.sh`：验证不修改 SSH、不重置防火墙、不硬编码开放端口及强确认短语。
- `tests/network_static.sh`：验证不执行远程脚本、不修改路由并保护 BBR 写操作。
- `tests/logs_static.sh`：验证日志行数上限、容器白名单及禁止清空和无限跟随。
- `tests/report_static.sh`：验证报告权限及禁止采集敏感系统来源。
- `tests/scheduler_static.sh`：验证固定 systemd 单元、强确认、应用白名单及禁止删除备份。

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
12. 网络诊断使用固定目标；BBR 只写独立 sysctl 文件，并在失败时恢复旧设置。
13. 在线更新必须先验证语义化版本并运行远程版本测试；禁止自动降级，失败时恢复安装前快照。
14. 插件不会自动加载；执行前必须验证 root 所有权、不可被非 root 写入、显示校验和并强确认。
15. 健康体检只读取状态；可选 Docker 功能不参与评分，建议不得自动执行修复。
16. 维护状态只允许使用 APT 模拟模式检测暂缓项，不执行 `full-upgrade`、发行版升级或自动重启。
17. 备份清理必须先预览并强确认，只处理严格命名的普通文件，不跟随符号链接。
18. 配置快照与支持包使用固定允许清单，不提供自动恢复，也不采集本地覆盖配置或原始日志。

## v1.4.0 备份生命周期

`modules/storage.sh` 负责归档识别、健康状态、完整性校验、磁盘余量和显式保留清理；`modules/config_snapshot.sh` 只处理固定允许清单；`modules/support.sh` 组合已有脱敏报告与备份摘要。三者都复用外部运行数据目录，不把备份或报告写入安装树。详细安全边界见 `backup-lifecycle.md`。
