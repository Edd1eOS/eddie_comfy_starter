# Third-Party Notices

源码仓库不包含运行环境和模型；另行构建的离线备用包包含以下未修改的组件，各自许可证与用途限制继续适用。

- ComfyUI v0.37.0：GPL-3.0，上游 https://github.com/Comfy-Org/ComfyUI/tree/v0.37.0 。对应 Python 源码及 LICENSE 随包保留在运行环境 ComfyUI 目录，便携环境来源/hash 见 configs/upstream-lock.json。
- CPython 和 Python 依赖：保留原环境中的许可证、NOTICE。版本及声明许可证见离线包 SBOM.json。PyTorch/CUDA/NVIDIA 二进制适用各自附带条款；不包含显卡驱动。
- WarriorMama777 的 AbyssOrangeMix 3 B4：CreativeML OpenRAIL-M；Lykon 的 DreamShaper XL Lightning：OpenRAIL++。许可证用途限制及原作者模型说明见 third_party/licenses，接收者仍须遵守这些限制。商用许可不保证训练数据或第三方权利，OrangeMix 合并来源存在额外不确定性。
- Comfy-Org 重打包的 Wan 2.2 TI2V 5B、VAE 和 UMT5 文本编码器：Apache-2.0，固定来源、版本、hash 见 model-manifests/green-flower-demo.json。

离线包的 Green Flower 演示不需要付费 API、第三方自定义节点下载或模型下载。其他工作流可能需要另配资源。源码项目地址：https://github.com/Edd1eOS/eddie_comfy_starter 。
