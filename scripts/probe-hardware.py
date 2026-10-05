"""Fail fast on an unavailable backend, including missing GPU kernels."""
import sys
import time
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
if backend == "xpu":
    # Availability and a tiny GEMM alone do not exercise diffusion operators.
    # Match the launcher's conservative FP32 mode; compare with CPU, not just NaNs.
    import torch.nn.functional as F
    torch.manual_seed(42)
    a = torch.randn(1, 4, 16, 16)
    w = torch.randn(8, 4, 3, 3) * 0.1
    q = torch.randn(1, 2, 16, 32)
    cases = {
        "convolution": lambda d: F.conv2d(a.to(d), w.to(d), padding=1),
        "attention": lambda d: F.scaled_dot_product_attention(q.to(d), q.to(d), q.to(d)),
    }
    print(f"Intel device: {torch.xpu.get_device_name(0)}; FP32 operator check", flush=True)
    for name, op in cases.items():
        started = time.monotonic()
        print(f"Checking {name}...", flush=True)
        expected = op("cpu")
        actual = op(device).cpu()
        assert torch.isfinite(actual).all(), f"{name}: non-finite output"
        torch.testing.assert_close(actual, expected, rtol=0.01, atol=0.001)
        print(f"{name}: passed in {time.monotonic() - started:.1f}s", flush=True)
print(f"Compute check passed: {backend}, PyTorch {torch.__version__}")
