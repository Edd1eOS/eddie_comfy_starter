# Model Manifests

每个模型记录来源、许可证链接、文件名、大小、目标目录、SHA-256/Blake3 和再分发限制；权重本身不进入 Git。

- `checkpoints.json`：已审核的 Checkpoint 清单，以及因许可证或来源问题暂未安装的候选模型。

这里的“允许商用”不等于没有限制。OpenRAIL 系列许可证仍要求遵守用途限制；模型训练素材和合并来源也可能带来额外的版权风险。模型文件只保存在本机 `data/userdata/models/checkpoints/`，不会上传到 GitHub。
