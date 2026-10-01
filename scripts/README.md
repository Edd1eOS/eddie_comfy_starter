# scripts

`cuw.ps1` 是当前 Windows CLI 入口。复杂逻辑位于 `src/`，脚本只负责参数转发和退出码。

当前命令：

- `setup`：安装并校验固定版本依赖。
- `start`：启动 ComfyUI，报告地址、PID 与日志位置。
- `stop`：安全停止本项目启动的实例。
- `doctor`：执行只读环境诊断并给出修复建议。
- `status`：显示当前状态、地址和存储位置。
- `models`：显示经过审核的 Hugging Face 模型及本机状态。
- `download-model -ModelId <名称> -AcceptLicense`：下载模型到当前 Checkpoints 目录，并校验文件大小和 SHA-256。
- `open-ui`、`open-models`、`open-workflows`、`open-output`：打开对应界面或目录。

`update` 和 Linux/macOS shell 入口尚未实现。脚本不得提交、输出或上传密钥，也不得把模型、input 或 output 写入 Git 工作区。
