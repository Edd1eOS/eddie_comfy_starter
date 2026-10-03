# 上游评估

核心上游已确认为 [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI)。当前任务从“寻找替代 Core”调整为评估官方组件的组合、版本与许可证边界。

Windows NVIDIA MVP 已锁定官方 ComfyUI v0.37.0 便携发布资产。其他硬件包和 Agent 组件仍需分别评估。

## 候选记录

| 候选 | 版本或 commit | 许可证 | 活跃度 | Windows/Linux | 图片能力 | 视频能力 | 安装复杂度 | 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ComfyUI Windows Portable NVIDIA | v0.37.0 | Core GPL-3.0；捆绑依赖各自许可 | 官方持续发布 | Windows + NVIDIA | 已验证启动 | Core 支持，工作流待验证 | 启动器自动下载 | Windows MVP 基线 |

## 评估维度

- 许可证是否允许预期的使用、修改和分发方式。
- release/tag 是否稳定，是否可固定到不可变 commit。
- Windows、Linux、CUDA 与主要 GPU 档位的兼容性。
- 图片和视频工作流所需节点的成熟度、维护状态与冲突风险。
- 安装、升级、回滚、离线使用和自动化测试难度。
- 已知安全问题、依赖供应链风险和模型许可证限制。

## 选型输出

确定上游后，应记录选择理由、明确版本、许可证链接、被否决候选及原因，并同步建立以下锁定清单：

- ComfyUI 上游版本锁定。
- `configs/custom-nodes.lock.yaml`：每个节点固定到 commit。
- `configs/models.lock.yaml`：每个模型记录来源、许可证与 SHA-256。

## 官方组件候选

| 组件 | 作用 | 许可证/边界 | 当前方向 |
| --- | --- | --- | --- |
| [ComfyUI Core](https://github.com/Comfy-Org/ComfyUI) | 节点图、推理引擎、原生 API | GPL-3.0；模型另有许可证 | v0.37.0 Windows NVIDIA 便携资产已锁定 |
| [Comfy Desktop](https://github.com/Comfy-Org/Comfy-Desktop) | 桌面安装、隔离环境、升级与回滚 | AGPL-3.0-or-later/商业路径，发布前复核 | 参考并评估复用，不默认嵌入 |
| [comfy-cli](https://github.com/Comfy-Org/comfy-cli) | 安装、启动、模型、节点、快照 | GPL-3.0，发布前复核 | 首选生命周期底层 |
| [comfy-api-proxy](https://github.com/Comfy-Org/comfy-api-proxy) | 稳定、可恢复的 API v2 | MIT，发布前复核 | 首选程序接口 |
| [Comfy MCP](https://github.com/Comfy-Org/comfy-mcp) | Agent/MCP 接入 | AGPL-3.0-or-later/商业路径，beta | 优先复用，外加我们的高层工具与安全策略 |

任何组合发布前都要做正式许可证审查，并保留第三方声明。模型权重与 Custom Nodes 的许可证不因 Core 许可证而自动获得再分发权。

任何版本升级都必须先通过代表性的图片与视频工作流回归测试。

## Hardware distribution verification (2026-10-03)

Verified release assets and SHA-256 digests via `https://api.github.com/repos/Comfy-Org/ComfyUI/releases/tags/v0.37.0`: official NVIDIA, NVIDIA CUDA 12.6, AMD and Intel portable archives exist. The pinned upstream `.ci/windows_amd_base_files/run_amd_gpu.bat` and `.ci/windows_intel_base_files/run_intel_gpu.bat` both launch embedded Python with `--windows-standalone-build`; CPU additionally uses `--cpu`. These are upstream ComfyUI GPL-3.0 packages with bundled dependency licenses, not newly licensed assets. No model weights are included in our Git repository.

Sources: [release](https://github.com/Comfy-Org/ComfyUI/releases/tag/v0.37.0), [pinned README](https://github.com/Comfy-Org/ComfyUI/blob/v0.37.0/README.md). AMD/Intel support is conditional on compatible device/driver; no physical AMD/Intel validation has been performed here. See `HARDWARE.md`.
