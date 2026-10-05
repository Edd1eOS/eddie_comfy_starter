# Windows hardware environments

The launcher persists the selected profile in `<DataRoot>/hardware.json`. An absent file retains the existing NVIDIA default. Runtime directories are separate under `runtime/versions`; CPU intentionally reuses the NVIDIA portable with `--cpu`. Models, workflows and output paths do not change. Switching is rejected while the launcher-owned process is live. Only setup accepts the CLI `-Hardware` option:

```powershell
.\scripts\cuw.ps1 setup -Hardware amd
```

Values: `nvidia`, `nvidia-legacy`, `amd`, `intel`, `cpu`. Installation is explicit, not inferred from a possibly incomplete hardware detection result. Drivers are not installed automatically. macOS/Linux are not supported by this Windows launcher.

`configs/hardware-profiles.json` pins SHA-256 digests from the v0.37.0 GitHub release API. Setup selects an asset from this allowlist, verifies its archive, extracts isolated Python, and tests a small tensor matrix multiplication on the selected backend. Intel additionally checks FP32 convolution and attention against CPU reference results. Start repeats the probe; doctor reports it. Probes have a 240-second deadline and retained logs; a timeout kills only that probe and records failure. No silent CPU fallback. A failed probe is recorded and does not display the environment as ready. Older existing NVIDIA installations remain discoverable and are checked on start.

Intel uses `--force-fp32 --fp32-text-enc --lowvram --disable-dynamic-vram --use-split-cross-attention`. These settings avoid automatic half precision and place the text encoder on CPU while sampling remains on XPU. This is a conservative default, not an Arc performance optimization. SYCL persistent compilation cache stays in `<DataRoot>/cache/intel-sycl`, inherited only by launched child processes; no machine/user environment or system Python is changed. The official upstream runtime is unmodified. Existing Intel installations receive these launch settings without reinstalling the archive. Restart the launcher and its Intel service to apply them.

Validated on 2026-10-04: Core Ultra 9 275HX integrated `Intel(R) Graphics`, driver 32.0.101.8331, bundled PyTorch 2.13.0+xpu. SD1.5 OrangeMix, 512×512, 12 Euler steps produced a coherent image: first FP32 run 180.67 seconds, subsequent launcher-path run 53.77 seconds (before adding split attention). Native LoRA with split attention, `training_dtype=fp32`, `lora_dtype=fp32`, rank 2 and two steps saved finite, updated weights. First step took about 447 seconds, second about 2 seconds, total graph 459.45 seconds. A five-minute deadline was insufficient; cold compilation is a plausible explanation, not a proven sole cause. The attention change and longer deadline were tested together. This does **not** establish support for older UHD/Iris, Arc, all video models or full LoRA training. An Intel i7 CPU name alone does not identify GPU support.

NVIDIA and CPU were exercised on the development machine. A fresh Intel package was also installed and tested on its Intel integrated GPU; this is not Arc acceptance. See [the detailed generation and native-training validation report](HARDWARE_VALIDATION_2026_10_04.md) for successes, failures and test limits. AMD and legacy NVIDIA still lack physical-device validation. Compatibility depends on drivers, model operators and custom nodes; passing the probe is not a promise every workflow works. The existing offline NVIDIA ZIP is not a universal package and has not been rebuilt for this change.

Updating upstream remains a manual reviewed lock change. No automatic cross-backend update or deletion of old environments is performed.

Final shipped-settings retest: 512×512 generation completed in 36.90 seconds,
and the same two-step FP32 LoRA smoke in 18.14 seconds after warm-up. Both output
and saved weights were checked. These tiny synthetic training timings must not
be extrapolated to a full-resolution character dataset.
