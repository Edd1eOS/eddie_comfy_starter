# AGENTS.md

本文件适用于整个 `comfyui-media-workbench` 仓库。

## 当前阶段

项目处于 Phase 1。官方组件与产品边界已明确，下一步验证精确版本、锁定格式和最小原型；不声称尚未实现的安装或运行能力。

## 修改规则

- 保持 Windows PowerShell 与 Linux/macOS shell 的入口语义一致。
- 自有代码放入 `src/`；不要直接修改未记录版本的上游源码。
- 新增或升级 Custom Node 时，必须更新节点锁定清单并记录 commit。
- Custom Node 是启动时执行的 Python 代码；只允许白名单、精确版本/hash，并要求人工批准安装或更新。
- 新增或升级模型时，必须更新模型锁定清单、许可证信息和 SHA-256。
- 图片与视频工作流必须声明节点、模型和运行参数依赖。
- 不得提交模型、密钥、`.env`、用户 input 或生成 output。
- 大型运行数据、缓存和日志必须保存在仓库外或被 `.gitignore` 排除。
- 原生 API 与 MCP 默认只监听 loopback；不得在无鉴权和网络边界的情况下开放公网。
- 付费 Partner/API 节点必须在工作流元数据和执行确认中明确标注。

## 验证要求

实现功能后至少运行相应单元测试和最小烟测。涉及生命周期流程时，应验证 `setup`、`start`、`stop`、`doctor`、`update` 的成功路径和可理解的失败提示。

## 文档要求

行为、配置格式、依赖或兼容性变化必须同步更新 README、架构文档或路线图。上游选型结论应写入 `docs/UPSTREAM_EVALUATION.md`，并保留许可证依据。
