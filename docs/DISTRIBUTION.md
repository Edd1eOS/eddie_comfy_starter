# Distribution Plan

## 目标结构

```text
launcher/          我们的工作站与资产中心
integrations/mcp/  官方 MCP 配置与高层工具适配
profiles/          硬件、版本和功能 Profile
model-manifests/   模型来源、许可证、hash 与目标目录
node-locks/        Custom Node 固定版本与兼容性
workflows/         可提交的精选工作流
policies/          离线、付费节点、资源和安全策略
scripts/           setup/start/stop/doctor/update
```

ComfyUI 及官方组件在 setup 时按锁定版本获取，不复制未经评估的上游源码。模型通过 manifest 下载到仓库外共享库，下载前展示大小和许可证，完成后校验 hash。

## 克隆体验

```text
git clone <future-github-repository>
cd comfyui-media-workbench
双击 Start ComfyUI Workbench.cmd
```

当前 Windows MVP 自动选择 NVIDIA 官方便携包，允许选择数据目录，并默认禁用 Partner/API 节点。后续向导再加入 GPU 档位和首个工作流包。服务仅绑定 `127.0.0.1`。

## 分发与许可证

GitHub 仓库只发布我们的代码、配置、manifest、工作流和文档。是否嵌入 GPL/AGPL 组件取决于最终许可证审查；模型和第三方节点按各自条款获取。Release 必须包含第三方许可证、NOTICE、SBOM、锁定版本和校验和。
