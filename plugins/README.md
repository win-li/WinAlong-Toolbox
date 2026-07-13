# 插件目录

插件文件名必须为 `<id>.plugin.sh`，由 root 所有，且组和其他用户不可写。

每个插件必须声明 `WAT_PLUGIN_ID`、`WAT_PLUGIN_NAME`、`WAT_PLUGIN_VERSION`，并实现 `wat_plugin_run` 函数。插件只在用户查看校验和并输入 `RUN` 后于子 shell 中执行。

管理员自定义插件请放到 `/etc/winalong-toolbox/plugins`，该目录在卸载时保留。
