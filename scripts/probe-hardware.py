"""Fail fast on an unavailable backend, including missing GPU kernels."""
import sys
import torch

backend = sys.argv[1]
if backend == "cpu":
    device = "cpu"
elif backend == "xpu":
    assert hasattr(torch, "xpu") and torch.xpu.is_available(), "Intel XPU unavailable"
    device = "xpu"
elif backend in ("cuda", "hip"):
    assert torch.cuda.is_available(), "GPU unavailable; check driver and supported model"
    assert bool(torch.version.hip) == (backend == "hip"), "Wrong PyTorch backend"
    device = "cuda"
else:
    raise ValueError("Unknown backend")
x = torch.ones((16, 16), device=device)
assert (x @ x).sum().item() == 4096
print(f"Compute check passed: {backend}, PyTorch {torch.__version__}")
