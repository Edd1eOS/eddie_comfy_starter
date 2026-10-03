# ComfyUI Media Workbench

基于官方 [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) 的本地图片与视频工作站。启动器支持 Windows，提供 NVIDIA、AMD、Intel 和 CPU 安装选项。

## Python 版本需求

无需预装 Python。点击「选择显卡 / 安装环境」，选择设备后自动下载固定版本的官方 ComfyUI v0.37.0 对应便携包（引擎、独立 Python 和依赖），不修改系统 Python 或 `PATH`。

NVIDIA 分新卡与旧卡环境；AMD 需 ROCm 支持的型号，Intel 需 XPU 支持的型号（如兼容的 Arc），两者尚未在本项目实机验证。安装后自动测试计算能力，不兼容会报错；驱动需自行安装。CPU 不需要独立显卡，但很慢。现有离线备用包仍仅为 NVIDIA 版本。

## 使用方式

在准备保存项目的文件夹中打开 PowerShell，执行（需要已安装 Git，不需要 Git LFS）：

```powershell
git clone https://github.com/Edd1eOS/eddie_comfy_starter.git
cd eddie_comfy_starter
& ".\Start ComfyUI Workbench.cmd"
```

没有 Git：在 GitHub 点击 **Code → Download ZIP**，完整解压后双击 `Start ComfyUI Workbench.cmd`，不要在压缩包内直接运行。

首次使用：选择显卡并一键安装 → 浏览并下载模型，或设置已有模型目录 → 打开创作界面 → 选择与模型匹配的工作流并运行。切换硬件前先停止服务；不同环境分开保存，共用模型、工作流与输出目录。

源码仓库不包含运行环境和模型，也不使用 Git LFS；首次需要联网下载数 GB 环境和所选模型，不是克隆后立即离线出图。完整离线包是另行分发的文件，包含环境及所需模型时才可解压后使用；仍需兼容的显卡和驱动。

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
