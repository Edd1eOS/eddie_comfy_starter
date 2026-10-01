# Launcher

Windows 启动器使用系统自带的 Windows PowerShell 与 WPF，不要求用户预装 Python 或 .NET SDK。

- `ComfyUIWorkbench.ps1`：界面与操作编排。
- `ComfyUIWorkbench.xaml`：界面布局和视觉样式。
- 首页只展示准备/打开、停止、模型库、模型文件夹、工作流、输出、检查问题和存储位置。
- 模型库读取 `model-manifests/checkpoints.json`，仅展示审核通过的条目；下载前显示大小与许可证提示。
- ComfyUI 原生 Web 界面继续负责节点编辑、队列和预览。

界面文字与名词说明遵循 [`docs/UI_SPEC.md`](../docs/UI_SPEC.md)。
