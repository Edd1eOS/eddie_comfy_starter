# Windows hardware environments

The launcher persists the selected profile in `<DataRoot>/hardware.json`. An absent file retains the existing NVIDIA default. Runtime directories are separate under `runtime/versions`; CPU intentionally reuses the NVIDIA portable with `--cpu`. Models, workflows and output paths do not change. Switching is rejected while the launcher-owned process is live. Only setup accepts the CLI `-Hardware` option:

```powershell
.\scripts\cuw.ps1 setup -Hardware amd
```

Values: `nvidia`, `nvidia-legacy`, `amd`, `intel`, `cpu`. Installation is explicit, not inferred from a possibly incomplete hardware detection result. Drivers are not installed automatically. macOS/Linux are not supported by this Windows launcher.

`configs/hardware-profiles.json` pins SHA-256 digests from the v0.37.0 GitHub release API. Setup selects an asset from this allowlist, verifies its archive, extracts isolated Python, and tests a small tensor matrix multiplication on the selected backend. Start repeats the probe; doctor reports it. No silent CPU fallback. A failed probe is recorded and does not display the environment as ready. Older existing NVIDIA installations remain discoverable and are checked on start.

NVIDIA/CPU can be validated on the development machine. AMD, Intel and legacy NVIDIA installation paths are implemented but have not been tested on corresponding physical hardware. Compatibility depends on drivers, model operators and custom nodes; passing the probe is not a promise every workflow works. The existing offline NVIDIA ZIP is not a universal package and has not been rebuilt for this change.

Updating upstream remains a manual reviewed lock change. No automatic cross-backend update or deletion of old environments is performed.
