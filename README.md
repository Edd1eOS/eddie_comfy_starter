# ComfyUI Media Workbench

面向图片与视频生成的可复现 ComfyUI 工作站封装。项目当前处于 **Phase 0：架构与仓库骨架**，尚未提供可运行安装包。

## 目标

- 提供统一的 `setup`、`start`、`stop`、`doctor`、`update` 操作。
- 固定 ComfyUI 上游版本、Custom Nodes 版本和模型清单。
- 让示例工作流在满足硬件要求的机器上可重复运行。
- 将代码、配置与运行数据分离，支持安全升级和回滚。

## 范围

本项目负责 ComfyUI 的安装包装、图片/视频工作流、节点依赖管理、环境诊断和分发体验。不在仓库中分发模型、用户输入或生成结果，也不替代 ComfyUI 本身。

## 目录

```text
configs/     可提交的默认配置及依赖锁定清单
docs/        架构、路线图和上游选型记录
examples/    最小可运行示例
models/      仅保留目录；模型文件禁止提交
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
