# Hardware / native LoRA validation — 2026-10-04

This is a compatibility smoke test, not a character-LoRA quality benchmark.
No custom nodes, new checkpoints, or training datasets were installed. Main
NVIDIA service/settings were preserved; temporary CPU/Intel services use
18288/18289 and project-local `data/hardware-validation/`.

## Environment

- Windows, Core Ultra 9 275HX, RTX 5070 Laptop 8 GB (driver 32.0.15.9201), Intel(R) Graphics
  integrated GPU (driver 32.0.101.8331), 32 GB system RAM.
- Official pinned ComfyUI v0.37.0 portable packages; NVIDIA torch 2.13.0+cu130,
  Intel torch 2.13.0+xpu, private Python 3.13.14.
- Intel archive SHA-256 matched `configs/hardware-profiles.json`; fresh
  installation completed and XPU matrix computation passed. It uses shared
  system memory; its reported ~16 GB is not dedicated GPU VRAM.
- A separate Linear/AdamW backward-and-update probe also passed under the
  ComfyUI Intel Python (torch 2.13.0+xpu). This small operation test must not be
  confused with a complete diffusion-model training run.
- Existing AOM3B4_orangemixs checkpoint, no model copy/download. Diagnostic
  outputs remain Git-ignored and are labelled `synthetic-not-for-use`.

## Verified results

| Backend | Generation | Native Train LoRA |
| --- | --- | --- |
| NVIDIA | 512x512 / Euler / 12 steps / seed 42; successful PNG, visually coherent flowers/vase | 64x64 synthetic latent, 2 steps, rank 2, AdamW, BF16; saved weights |
| CPU | 256x256 / Euler / 4 steps / seed 42; successful PNG | BF16 fails on this CPU (`DNNL does not support bf16/f16 backward`); FP32 passes the same two-step smoke |
| Intel integrated XPU | **FP32 compatibility mode passes** 512x512 / Euler / 12 steps; initial run 180.67s, launcher-path rerun 53.77s; both images visually inspected. Original default-precision graph timed out at CLIP | **Two-step FP32 smoke passes with split attention and a longer deadline**, 459.45s total; first step ~447s, second ~2s. Saved finite, updated LoRA weights. Initial 300-second tests timed out |
| AMD / legacy NVIDIA | No matching physical hardware available | Not tested |

The validated NVIDIA, CPU and Intel LoRA files have 1,250 finite tensors and 282 nonzero
`lora_up.weight` matrices after optimization. This verifies graph execution,
backpropagation and persistence, **not useful learning, character likeness,
full-size training stability, other model families or acceptable speed**.

Intel **generation and minimal native-training smoke tests now pass in FP32
compatibility mode**. A timeout is not proof that
all Intel GPUs or all future runs are unsupported: cold kernel compilation,
driver behavior and model operations were not isolated. No Arc GPU was
available. A successful tiny AdamW test is insufficient to recommend this
machine's integrated GPU for native LoRA training. No global driver or
Python changes were made. Cleanup of the generated temporary Intel
archive/runtime was blocked by the execution policy; they remain under
`data/hardware-validation/intel/` (about 7.2 GiB). Logs/state are retained there
too. Main NVIDIA settings remain untouched. These artifacts are Git-ignored.

14 core tests, hardware selection/invalid-backend tests, CPU
setup/start/doctor/stop, launcher appearance, portable settings and external
model-path tests pass. CPU and Intel diagnostics do not alter the default
NVIDIA selection.

## Reproduction

- `tests/test-hardware.ps1 -Smoke`: existing-runtime CPU lifecycle and rejected
  wrong-backend checks, without downloading a fresh GPU environment.
- `tests/smoke-generation-api.py`: local idle-server generation test.
- `tests/smoke-training-api.py`: local idle-server native LoRA test. CPU/XPU
  use FP32; CUDA uses BF16. `--dtype` can explicitly override this for testing.
- `tests/smoke-backend-api.ps1 -Hardware cpu -Train`: isolated service, model
  references, generation, native training and stop. Intel requires its
  separately prepared runtime; no automatic third-party node installation.
- `-Hardware intel` now tests the shipped compatibility parameters:
  `--force-fp32 --fp32-text-enc --lowvram --disable-dynamic-vram --use-split-cross-attention`.
  `-TrainingOnly` checks native training separately; `-TimeoutSeconds` controls
  the workflow deadline (900 seconds by default, distinct from the 240-second
  operator-probe deadline). `-FullPrecision` remains a diagnostic legacy switch.

## Intel compatibility fix follow-up

The corrected launcher path generated
`hardware-validation/generation-20c7cfac0e49_00001_.png` on XPU in 53.77 seconds
(512x512, 12 steps, seed 42). The preceding FP32 diagnostic output
`generation-2d4db8288367_00001_.png` took 180.67 seconds. Both were visually
checked for coherent flowers and a vase, not merely file existence.
FP32 convolution and attention match CPU references in the strengthened probe.
The NVIDIA isolated regression also generated a 512x512 image in 3.87 seconds;
CPU lifecycle, failure/timeout recording, private cache restoration and UI tests pass.

Cache configuration follows [Intel's SYCL environment-variable documentation](https://www.intel.com/content/www/us/en/docs/dpcpp-cpp-compiler/developer-guide-reference/2025-2/supported-environment-variables.html).
Only the launched process inherits the project-local cache settings.

Intel native training then succeeded with split attention:
`hardware-validation/synthetic-not-for-use-2da616228e2b_2_steps_00001_.safetensors`.
All 1,250 tensors are finite and 282 LoRA up-projection matrices changed from zero.
The first step's long wait means the previous five-minute deadlines could truncate
initial compilation. The attention implementation and deadline changed together;
this test does not isolate which change was necessary. Training remains a synthetic
64x64-latent, rank-2, two-step smoke test, not a real dataset/character benchmark.
The CPU retest also saved verified updated weights (`synthetic-not-for-use-e7a50168ee4f`).

Final shipped-settings rerun (no diagnostic overrides): generation
`generation-a78fea6317e8_00001_.png` completed in **36.90 seconds**, visually
coherent. Native training `synthetic-not-for-use-b7628f16a371_2_steps_00001_.safetensors`
completed in **18.14 seconds** including preparation (two training steps ~12.6s).
Its 1,250 tensors are finite and 282 up-projection matrices are nonzero. The
large cold/warm difference supports the warm-up explanation; it does not prove
that precision/attention changes alone fixed an upstream bug. All temporary
diagnostic services on ports 18288–18290 were stopped afterwards.

## Can ComfyUI replace Kohya?

This version includes experimental `Train LoRA` and `Save LoRA Weights` nodes
in `comfy_extras/nodes_train.py`, independently of the launcher-added Kohya
environment. It is a possible alternative training implementation, not just
a frontend to Kohya. Native training passed the limited NVIDIA/CPU checks
above. Merely loading an existing LoRA is not training. A hardware limitation
or unsupported driver is not solved automatically by changing the UI.

Primary source: [versioned ComfyUI native training implementation](https://github.com/Comfy-Org/ComfyUI/blob/v0.37.0/comfy_extras/nodes_train.py).
