# ComfyUI Media Workbench

基于官方 [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) 的本地图片与视频工作站。当前版本支持 Windows + NVIDIA。

## Python 版本需求

无需预装 Python。首次准备工作台时会下载官方 ComfyUI v0.37.0 NVIDIA 便携包，其中包含隔离的 Python 3.13，不修改系统 Python 或 `PATH`。

## 使用方式

双击根目录的 `Start ComfyUI Workbench.cmd`。

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
