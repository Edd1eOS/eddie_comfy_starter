# Product Specification

## 两个产品入口

### 1. 图形化工作站

- 安装、启动、停止、升级、回滚和环境诊断。
- 稳定/实验 Profile、多个隔离实例和 GPU/显存适配。
- 模型资产中心：来源、许可证、hash、大小、目录、兼容性和重复文件识别。
- Custom Node 中心：白名单、固定 commit/hash、依赖、快照、回滚和风险提示。
- 图片/视频工作流模板、参数表单、队列、历史和输出图库。
- 共享模型库，可通过官方 `extra_model_paths.yaml` 与其他 Stable Diffusion 工具复用。

### 2. Agent 工具服务

- 复用官方 comfy-mcp 与 API v2 proxy/SDK。
- 对 Codex/OpenClaw 提供高层、参数化工具，不要求 Agent 理解每个节点 ID。
- 异步提交任务，返回 job ID；支持状态、取消、日志摘要与产物读取。
- 每次结果保留 workflow 版本、模型 hash、节点版本、prompt、seed 和运行参数。
- 允许 Agent 查看生成结果后有限次数调整，但有最大迭代、批量、分辨率、GPU 时间和视频时长。

## MVP

- Windows 一键安装/启动/诊断，随后覆盖 Linux/macOS。
- 一个可复现图片工作流和一个声明硬件要求的视频工作流。
- 共享模型目录与模型 manifest。
- Custom Node lock、快照与回滚。
- 本地 UI 和首批高层 MCP 工具。
- 默认离线模式；启用 Partner/API 节点前展示费用与数据外发提示。

## 重要边界

- 本地开源推理没有平台 token 额度，不等于无限 GPU、无限时长或零成本。
- 工作流 JSON 可提交；模型、用户 input/output、缓存、日志和密钥不提交。
- Custom Nodes 是代码执行，不作为普通“素材”静默安装。
- 原生 API/MCP 默认只监听 loopback。
