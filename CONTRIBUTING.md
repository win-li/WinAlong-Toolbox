# 参与贡献

1. Fork 仓库并从 `main` 创建功能分支。
2. 所有 Bash 文件使用 `set -Eeuo pipefail`，公共逻辑放在 `lib/`，功能逻辑放在 `modules/`。
3. 系统写操作必须检查 root 权限、显示影响并要求明确确认。
4. 不得提交密码、Token、私钥、`.env`、服务器地址或未脱敏日志。
5. 不引入 DD 重装、修改 SSH 登录策略、代理、VPN 或任意开放端口功能，除非经过单独安全设计和审核。
6. 提交前运行 `bash tests/smoke.sh`；安装了 ShellCheck 时必须零告警。

提交信息建议使用 `feat:`、`fix:`、`docs:`、`test:` 或 `chore:` 前缀。安全问题请按 [SECURITY.md](SECURITY.md) 私密报告。
