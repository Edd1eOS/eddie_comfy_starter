# ComfyUI Media Workbench

基于官方 [Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) 的可复现生成式媒体工作站。它同时提供节点图形界面和 Agent 可调用工具，覆盖图片、视频以及后续音频/3D 工作流。项目当前处于 **Phase 1：官方组件调研与产品规格完成；实现尚未开始**。

## 目标

- 组合官方 Desktop、CLI、API proxy/SDK 与 MCP 能力，不重复制造已有组件。
- 提供统一的 `setup`、`start`、`stop`、`doctor`、`update` 操作和友好的本地启动/资产中心。
- 固定 ComfyUI 上游版本、Custom Nodes 版本和模型清单。
- 让示例工作流在满足硬件要求的机器上可重复运行。
- 将代码、配置与运行数据分离，支持安全升级和回滚。
- 让 Codex、OpenClaw 和其他 Agent 通过受限 MCP 工具运行参数化工作流。

## 范围

本项目负责 ComfyUI 的安装包装、资产中心、精选图片/视频工作流、节点依赖管理、环境诊断和 Agent 接入。不在仓库中分发模型、用户输入或生成结果，也不替代 ComfyUI 本身。

本地运行开源模型通常没有 SaaS token 额度，但仍受 GPU/显存、内存、磁盘、推理时间、电力、具体模型时长以及许可证限制；Partner/API 节点仍可能收费。因此不能承诺“无限时长、零成本”。

## 目录

```text
configs/     可提交的默认配置及依赖锁定清单
docs/        架构、路线图和上游选型记录
examples/    最小可运行示例
integrations/mcp/ 官方 MCP 配置与高层工具适配
launcher/    启动、资产与运行历史体验
model-manifests/ 模型来源、许可证和 hash
models/      仅保留目录；模型文件禁止提交
node-locks/  Custom Node 精确版本与风险记录
policies/    离线、付费节点、资源与安全策略
profiles/    经验证的硬件/模型/节点/工作流组合
scripts/     setup/start/stop/doctor/update 等入口
src/         本项目自己的包装层代码
tests/       单元测试、烟测和端到端测试
workflows/   可版本化的图片与视频工作流
```

## 可复现性约定

- ComfyUI 固定到明确的 tag 或 commit。
- Custom Nodes 通过 `configs/custom-nodes.lock.yaml`（规划中）记录仓库、commit 和兼容信息。
- 模型通过 `configs/models.lock.yaml`（规划中）记录来源、许可证、文件名、用途和 SHA-256；清单可提交，模型文件不可提交。
- 工作流 JSON 必须记录所需节点、模型标识、生成参数和兼容版本。

## 安全与数据

不得提交密钥、`.env`、模型、用户输入或生成输出。运行数据应位于仓库外的可配置目录；本地配置从 `.env.example` 复制并自行填写。

后续工作见 [路线图](docs/ROADMAP.md) 与 [上游评估模板](docs/UPSTREAM_EVALUATION.md)。

许可证将在上游选型与兼容性审查后确定。

详细产品边界、MCP 工具和分发方案见 `docs/PRODUCT_SPEC.md`、`docs/MCP_TOOL_PLAN.md` 与 `docs/DISTRIBUTION.md`。
