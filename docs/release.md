# v1.1.2 发布与验收

## 支持范围

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 12
- x86_64；其他架构尚未纳入正式验收

## 发布前检查

```bash
bash tests/smoke.sh
sudo bash install.sh
winalong --version
sudo winalong --doctor
sudo winalong --maintenance
```

必须确认所有 Bash 文件通过 `bash -n`；测试机安装 ShellCheck 时必须零告警。在线更新、插件执行、UFW、Fail2ban、BBR、应用备份和恢复均应在独立测试 VPS 验证。

## 当前验证记录

- Ubuntu 22.04.5 LTS / x86_64：已完成主菜单、在线更新、插件、Docker、Portainer、Nginx、Uptime Kuma、UFW、Fail2ban、BBR 和备份流程验证。
- Ubuntu 24.04 LTS：待独立测试机验证。
- Debian 12：待独立测试机验证。

未验证的平台不得标记为已通过。正式部署前应保留云平台快照和现有 SSH 会话。

## 安全边界

正式版不修改 OpenSSH 登录配置，不提供 DD 重装、代理、VPN、任意端口开放或远程脚本管道执行。Docker Web 服务默认绑定回环地址，远程访问使用 SSH 隧道。
