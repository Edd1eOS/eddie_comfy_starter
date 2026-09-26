# MCP Tool Plan

官方 [Comfy MCP](https://github.com/Comfy-Org/comfy-mcp) 已覆盖大量底层功能。本项目不重造完整 MCP，而是在其上定义更稳定、更安全的高层工具与默认策略。

## 高层 MVP 工具

| 工具 | 用途 | 风险 |
| --- | --- | --- |
| `comfy_doctor` | 检查服务、GPU、模型、节点和工作流依赖 | 只读 |
| `comfy_list_profiles` | 列出已验证的图片/视频 Profile | 只读 |
| `comfy_list_workflows` | 列出可参数化工作流及硬件要求 | 只读 |
| `comfy_generate_image` | 用受支持参数启动图片任务 | 消耗本地 GPU；可能使用付费节点 |
| `comfy_generate_video` | 用受支持参数启动视频任务 | 高 GPU/磁盘消耗；严格限制时长 |
| `comfy_run_workflow` | 运行白名单内的工作流版本 | 只允许已验证依赖 |
| `comfy_get_job` | 查询进度、实际依赖、资源与结果 | 只读 |
| `comfy_cancel_job` | 取消队列或运行任务 | 改变运行状态 |
| `comfy_list_artifacts` | 列出任务输出与元数据 | 只读 |
| `comfy_get_artifact` | 获取一个允许目录内的产物 | 路径受限 |

模型/节点安装、任意 URL 下载和任意工作流执行不纳入默认 Agent 工具；它们属于管理面，需要人工确认、来源校验和许可证确认。

## 生成循环

Agent 可执行“生成 → 查看产物 → 调整 Prompt/seed/参数 → 再生成”，但服务端必须强制最大轮数、分辨率、批量、视频时长、并发和 GPU 时间。每轮保存完整可复现元数据。
