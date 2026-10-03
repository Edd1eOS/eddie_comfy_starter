"""Build an allowlisted ZIP64 portable distribution using the embedded Python."""
import argparse
import hashlib
import importlib.metadata
import json
import subprocess
import zipfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'ComfyUI-Workbench/'


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    files = {name: ROOT / name for name in tracked if name and (ROOT / name).is_file()}
    runtime = ROOT / 'data/runtime/versions/comfyui-v0.37.0-nvidia'
    if not (runtime / 'python_embeded/python.exe').is_file():
        raise RuntimeError('Prepare the pinned NVIDIA runtime before packaging')
    skip_parts = {'.git', '__pycache__', '.pytest_cache'}
    for path in runtime.rglob('*'):
        rel = path.relative_to(runtime)
        if not path.is_file() or any(p in skip_parts for p in rel.parts):
            continue
        if rel.parts[0] == 'ComfyUI' and len(rel.parts) > 1 and rel.parts[1] in {'input', 'output', 'temp', 'user'}:
            continue
        if path.suffix in {'.pyc', '.pyo', '.log'} or path.name.startswith('.env'):
            continue
        files[path.relative_to(ROOT).as_posix()] = path
    expected = {}
    for model in load(ROOT / 'model-manifests/checkpoints.json')['approved']:
        name = 'data/userdata/models/checkpoints/' + model['fileName']
        files[name] = ROOT / name
        expected[name] = (model['sizeBytes'], model['sha256'])
    for model in load(ROOT / 'model-manifests/green-flower-demo.json')['models']:
        name = 'data/userdata/models/' + model['path']
        files[name] = ROOT / name
        expected[name] = (model['size'], model['sha256'])
    for name in ['data/userdata/input/green-flower-reference.png',
                 'data/userdata/output/green-flower/emerald-meadow-8s_00001_.mp4',
                 'data/userdata/output/green-flower/keyframe_00003_.png',
                 'data/userdata/user/default/workflows/绿色花海-8秒视频演示.json',
                 'data/userdata/user/default/workflows/绿色花海-关键帧演示.json']:
        files[name] = ROOT / name
    for name, path in files.items():
        if not path.is_file() or path.is_symlink():
            raise RuntimeError('Missing file or unsupported symlink: ' + name)
        if name in expected and path.stat().st_size != expected[name][0]:
            raise RuntimeError('Model size mismatch: ' + name)
    for name in ['Apache-2.0.txt', 'CreativeML-OpenRAIL-M.txt', 'OpenRAIL-plusplus.txt']:
        if 'third_party/licenses/' + name not in files:
            raise RuntimeError('License must be tracked: ' + name)
    total = sum(p.stat().st_size for p in files.values())
    import shutil
    if shutil.disk_usage(args.output).free < total + 1024**3:
        raise RuntimeError('Insufficient space for the ZIP and safety margin')
    target = args.output / ('ComfyUI-Workbench-offline-NVIDIA-' + datetime.now().strftime('%Y%m%d') + '-' + commit[:7] + '.zip')
    packages = sorted([{'name': d.metadata.get('Name'), 'version': d.version,
                        'declaredLicense': (d.metadata.get('License-Expression') or d.metadata.get('License') or 'See bundled notices')[:400]}
                       for d in importlib.metadata.distributions()], key=lambda p: p['name'] or '')
    usage = ('离线便携版（Windows + NVIDIA）\n\n'
             '1. 完整解压到短路径，例如 D:\\ComfyUI。不要在压缩包内运行。\n'
             '2. 双击 Start ComfyUI Workbench.cmd，然后点击“打开创作界面”。\n'
             '3. 从“工作流”打开绿色花海演示，再运行。参考图、模型和示例输出均已放好。\n\n'
             '不需要安装 Python、Git 或配置 PATH；运行内置演示不需要联网。\n'
             '需要兼容的 NVIDIA 显卡驱动，已在 8 GB 显存设备验证。建议至少 40 GB 解压空间。\n'
             '首次加载模型需要等待；新模型、新节点和其他工作流可能仍需联网下载。\n'
             '视频演示为约 8 秒无声视频，不包含音乐或语音。\n'
             '模型许可证及用途限制见 THIRD_PARTY_NOTICES.md。\n')
    generated = {'portable.mode': b'Use package-local settings.\n',
                 '先看这里.txt': usage.encode('utf-8-sig'),
                 'SBOM.json': json.dumps({'sourceCommit': commit, 'pythonPackages': packages}, ensure_ascii=False, indent=2).encode('utf-8')}
    records = []
    print(f'Packing {len(files)} files, {total / 1e9:.2f} GB -> {target}', flush=True)
    with zipfile.ZipFile(target, 'x', compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for index, (name, path) in enumerate(sorted(files.items())):
            digest = hashlib.sha256()
            size = path.stat().st_size
            if size > 100_000_000 or index % 3000 == 0:
                print(f'[{index}/{len(files)}] {name} ({size / 1e6:.1f} MB)', flush=True)
            with path.open('rb') as source, archive.open(PREFIX + name, 'w', force_zip64=True) as dest:
                while block := source.read(8 * 1024**2):
                    digest.update(block)
                    dest.write(block)
            sha = digest.hexdigest()
            if name in expected and sha != expected[name][1]:
                raise RuntimeError('Model SHA-256 mismatch: ' + name)
            records.append({'path': name, 'size': size, 'sha256': sha})
        for name, value in generated.items():
            archive.writestr(PREFIX + name, value)
            records.append({'path': name, 'size': len(value), 'sha256': hashlib.sha256(value).hexdigest()})
        archive.writestr(PREFIX + 'FILE_MANIFEST.json', json.dumps(records, ensure_ascii=False, indent=2))
    print('Verifying every archived file (CRC + SHA-256)...', flush=True)
    with zipfile.ZipFile(target) as archive:
        for index, record in enumerate(records):
            digest = hashlib.sha256()
            with archive.open(PREFIX + record['path']) as source:
                while block := source.read(8 * 1024**2):
                    digest.update(block)
            if digest.hexdigest() != record['sha256']:
                raise RuntimeError('Archive verification failed: ' + record['path'])
            if index % 5000 == 0:
                print(f'Verified {index}/{len(records)}', flush=True)
    print('Computing archive checksum...', flush=True)
    with target.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    target.with_suffix('.zip.sha256').write_text(digest + '  ' + target.name + '\n', encoding='ascii')
    (args.output / '使用说明.txt').write_text(usage, encoding='utf-8-sig')
    print(f'COMPLETE {target}\nSHA256 {digest}', flush=True)


if __name__ == '__main__':
    main()
