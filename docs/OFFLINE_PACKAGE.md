# 离线备用包

GitHub 只放源码、锁定清单和工作流，不包含 Python、模型和用户素材。首次使用源码版仍需联网准备环境。

备用包是 Windows NVIDIA 便携 ZIP：完整解压后双击 `Start ComfyUI Workbench.cmd`，不需要另装 Python、Git 或配置 PATH。需要系统已有兼容的 NVIDIA 驱动；8 GB 显存是本机验证配置，不保证所有模型参数都能运行。建议短路径、NTFS 磁盘，至少 40 GB 解压空间（保留 ZIP 时另计）。

包含独立环境、两个图片模型、Wan 视频模型及组件、Green Flower 工作流、输入参考图和演示输出。`portable.mode` 使启动器使用包内设置，默认读取自身 `data`，不读取其他安装的全局路径。外接模型目录仍需用户自行配置。

构建：用已准备好的包内 Python 运行 `scripts/build-offline.py --output <备用包目录>`。只收集 Git 跟踪文件、锁定模型、运行环境及指定演示素材，不收集全局配置、运行状态、密钥或其他用户作品。模型 SHA-256 必须通过验证。保留上游源码/许可证，附 SBOM、逐文件校验清单和 ZIP 校验文件。

第三方条款见 `THIRD_PARTY_NOTICES.md` 和 `third_party/licenses`。模型并非无条件商用授权，尤其深渊橘的合并来源存在权利不确定性；商业分发前应另行审查。
