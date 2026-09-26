# AGENTS.md

本文件适用于整个 `comfyui-media-workbench` 仓库。

## 当前阶段

项目处于 Phase 0。优先完善边界、目录、锁定格式和验收标准，不声称尚未实现的安装或运行能力。

## 修改规则

- 保持 Windows PowerShell 与 Linux/macOS shell 的入口语义一致。
- 自有代码放入 `src/`；不要直接修改未记录版本的上游源码。
- 新增或升级 Custom Node 时，必须更新节点锁定清单并记录 commit。
- 新增或升级模型时，必须更新模型锁定清单、许可证信息和 SHA-256。
- 图片与视频工作流必须声明节点、模型和运行参数依赖。
- 不得提交模型、密钥、`.env`、用户 input 或生成 output。
- 大型运行数据、缓存和日志必须保存在仓库外或被 `.gitignore` 排除。

## 验证要求

实现功能后至少运行相应单元测试和最小烟测。涉及生命周期流程时，应验证 `setup`、`start`、`stop`、`doctor`、`update` 的成功路径和可理解的失败提示。

## 文档要求

行为、配置格式、依赖或兼容性变化必须同步更新 README、架构文档或路线图。上游选型结论应写入 `docs/UPSTREAM_EVALUATION.md`，并保留许可证依据。
