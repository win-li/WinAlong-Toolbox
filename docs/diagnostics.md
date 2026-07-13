# 日志、诊断报告与自动备份

## 日志中心

日志中心从主菜单 `11` 进入。WinAlong 日志和容器日志默认显示最后 100 行，配置范围限制为 10 到 500 行。容器只能从 Nginx、Uptime Kuma 和 Portainer 白名单中选择，不接受任意容器名或额外 Docker 参数。

日志不是自动脱敏内容。应用日志可能包含访问地址、路径或用户输入，复制给他人前必须人工检查。

## 脱敏诊断报告

```bash
sudo winalong --report
```

报告保存到 `/var/log/winalong-toolbox/reports/`，目录权限 `700`，文件权限 `600`。报告包含系统版本、内核、架构、资源、维护状态、失败服务数量、UFW、Fail2ban、BBR、Docker 容器状态和 WinAlong 日志计数。

报告不采集：

- 主机名、IPv4、IPv6 或 MAC 地址
- 环境变量、`.env`、密码、Token 或私钥
- SSH 配置、防火墙规则明细
- Docker Inspect 数据或原始应用日志

报告仍应在分享前人工检查，特别是自定义容器名称。

## 自动备份

```bash
sudo winalong --backup-schedule
```

启用操作要求输入 `ENABLE`，停用要求输入 `DISABLE`。计划使用项目固定拥有的 `winalong-backup.service` 和 `winalong-backup.timer`，默认每天 03:30 执行，并有最多 10 分钟随机延迟。

任务只处理已经部署的 Nginx 和 Uptime Kuma。备份时应用会短暂停止以确保数据一致性；未部署应用会被跳过。工具不会自动删除历史备份。卸载工具时会删除项目自己的 systemd 单元，但保留日志和备份文件。
