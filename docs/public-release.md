# 公开发布检查清单

## 更改仓库可见性之前

- 确认 `git status` 干净，完整烟雾测试通过。
- 检查当前文件和 Git 历史中没有密码、Token、私钥、服务器地址或未脱敏日志。
- 确认 `LICENSE`、`SECURITY.md`、`CONTRIBUTING.md` 和更新日志已提交。
- 从未登录 GitHub 的环境测试 HTTPS 克隆和在线更新。
- 确认 Ubuntu 24.04 与 Debian 12 尚未验证的状态没有被误标为通过。

## 公开后验证

```bash
git clone https://github.com/win-li/WinAlong-Toolbox.git
cd WinAlong-Toolbox
bash tests/smoke.sh
sudo bash install.sh
```

快速安装（便利性优先，会直接信任远程引导脚本）：

```bash
curl -fsSL https://raw.githubusercontent.com/win-li/WinAlong-Toolbox/main/bootstrap.sh | sudo bash
```

发布 GitHub Release 后，还应在无登录浏览器中验证源码压缩包可下载。
