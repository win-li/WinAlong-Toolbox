# 架构说明

WinAlong Toolbox 采用小型、可组合的 Bash 模块架构。

- `toolbox.sh`：程序入口，仅加载配置、公共库和模块，并负责主菜单调度。
- `lib/common.sh`：权限、交互确认、系统识别与日志等公共能力。
- `lib/ui.sh`：统一的标题、菜单和消息输出。
- `modules/`：按功能域组织业务逻辑；v0.1.0 仅提供只读系统检查。
- `config/default.conf`：可提交的默认配置；本地覆盖使用 `config/local.conf`。
- `tests/smoke.sh`：关键文件、Bash 语法与 ShellCheck 烟雾测试。

## 设计原则

1. 主入口不承载具体系统操作。
2. 默认功能应可重复执行，并优先采用只读检查。
3. 任何会修改系统状态的功能必须明确提示并单独实现。
4. 运行日志与备份位于安装目录之外，卸载时默认保留。
5. 当前支持目标为 Ubuntu 22.04、Ubuntu 24.04 和 Debian 12。
