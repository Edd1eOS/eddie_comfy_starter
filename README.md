# ComfyUI Media Workbench

基于官方 [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) 的本地图片与视频工作站。当前版本支持 Windows + NVIDIA。

## Python 版本需求

无需预装 Python。首次准备工作台时会下载官方 ComfyUI v0.37.0 NVIDIA 便携包，其中包含隔离的 Python 3.13，不修改系统 Python 或 `PATH`。

## 使用方式

双击根目录的 `Start ComfyUI Workbench.cmd`。

共用其他工具的模型：点击「模型路径设置」，按类型添加目录并保存；停止并重新启动创作服务后刷新 WebUI 生效。原目录保留，移除引用不会删除文件。

本机视频演示：在 ComfyUI 左侧「工作流」打开「绿色花海-8秒视频演示」，点击「运行」。演示使用的参考图和视频模型已在本机准备；Git 仓库不包含这些大文件，依赖见 `model-manifests/green-flower-demo.json`。

## 目录

- `configs/`：版本和默认配置
- `docs/`：架构、界面和路线图
- `launcher/`：图形启动器
- `model-manifests/`：模型来源、许可证和校验信息
- `node-locks/`：Custom Node 固定版本和风险记录
- `profiles/`：经过验证的硬件组合
- `scripts/`：命令行入口
- `src/`：工作台核心代码
- `tests/`：自动化测试和视觉检查
- `workflows/`：图片与视频工作流
