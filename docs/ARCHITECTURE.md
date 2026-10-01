# 架构

## 设计目标

本项目在官方 ComfyUI 生态之上增加可复现、可诊断、可升级的发行与产品层，同时保持上游与本项目代码边界清晰。官方现有 Desktop、CLI、API v2 proxy/SDK 和 MCP；我们优先组合和加固，而不是从零重写。

## 分层

```text
我们的 WPF Launcher / Asset Center / Preset UI
            ├─ 官方 Windows Portable：隔离 Python、PyTorch 与 ComfyUI
            ├─ ComfyUI：节点图 UI 与本地推理
            ├─ 原生本地 API：健康检查、队列与工作流执行
            └─ 后续 MCP：Codex / OpenClaw / Agent 接入
                         ↓
固定版本的 Core + Custom Nodes + Workflows
                         ↓
模型、input、output、缓存等仓库外运行数据
```

- `scripts/cuw.ps1` 提供当前 Windows CLI 入口，不承载复杂业务逻辑。
- `src/` 负责配置解析、安装编排、健康检查和进程管理。
- `configs/` 保存默认配置以及可审计的上游、节点和模型锁定清单。
- `workflows/` 保存可复现的图片与视频工作流。
- `launcher/` 与 `profiles/` 保存我们的启动/资产体验和可复现配置。
- `integrations/mcp/` 保存官方 MCP 的配置、限制与高层工具适配，不复制其源码。

## 依赖锁定

上游 ComfyUI 必须固定 tag 或 commit。Custom Nodes 锁定清单至少包含名称、仓库地址、commit、用途和兼容约束。模型锁定清单至少包含稳定标识、来源、许可证、文件名、SHA-256、用途和最低资源要求。

工作流不得依赖“本机刚好存在”的匿名节点或模型；每个依赖都必须能映射到锁定清单。允许用户使用自有模型，但这类工作流应明确标为不可完全复现。

## 数据边界

模型、用户输入、生成输出、缓存、日志和密钥不进入 Git。默认通过环境变量或本地配置指向仓库外目录。删除代码仓库不应删除用户资产。

## 目标命令契约

- `setup`：校验平台和硬件，安装固定版本依赖，不下载未获用户确认的大型模型。
- `start`：使用显式配置启动服务，输出访问地址和日志位置。
- `stop`：仅停止本项目启动的进程，重复执行仍安全。
- `doctor`：只读检查运行时、GPU、磁盘、端口、节点和模型完整性，并给出修复建议。
- `update`：备份配置与工作流，按锁定版本升级并支持回滚。

当前 Windows MVP 已实现 `setup`、`start`、`stop`、`status`、`doctor`、目录入口，以及基于审核清单的 `models` / `download-model`。模型下载使用 Hugging Face HTTPS 通道，支持续传，并在进入 Checkpoints 目录前校验大小与 SHA-256。`update`、回滚及 Linux/macOS shell 入口仍属于后续阶段。

## 安全边界

安装脚本不得静默执行来源不明的代码。节点与模型下载必须来自锁定清单，校验版本或哈希，并记录许可证。日志不得打印密钥或完整敏感路径。

原生 API 只绑定 `127.0.0.1`。Custom Nodes 视为任意代码执行，必须使用白名单、固定 commit/hash、快照和人工批准。Agent 运行还需限制最大分辨率、批量、迭代次数、GPU 时间和视频时长。
