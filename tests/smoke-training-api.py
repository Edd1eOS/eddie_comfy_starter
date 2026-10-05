"""Two-step synthetic native LoRA smoke test, NOT dataset/quality acceptance.

Uses an existing local server/checkpoint, refuses a busy queue, writes a uniquely
named diagnostic LoRA to output/hardware-validation. Installs no custom nodes.
"""
import argparse
import json
import time
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8188)
parser.add_argument('--dtype', choices=['auto','bf16','fp32'], default='auto')
parser.add_argument('--timeout', type=int, default=300)
args = parser.parse_args()
base = f'http://127.0.0.1:{args.port}'
def call(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=data, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

queue = call('/queue')
if queue['queue_running'] or queue['queue_pending']:
    raise SystemExit('Server is busy; no test submitted.')
schema = call('/object_info/TrainLoraNode')['TrainLoraNode']['input']['required']
inputs = {key: value[1]['default'] for key, value in schema.items() if len(value) > 1 and 'default' in value[1]}
backend = call('/system_stats')['devices'][0]['type']
dtype = ('bf16' if backend == 'cuda' else 'fp32') if args.dtype == 'auto' else args.dtype
inputs.update(model=['1', 0], latents=['3', 0], positive=['2', 0], steps=2,
              rank=2, batch_size=1, training_dtype=dtype, lora_dtype='fp32',
              seed=42, optimizer='AdamW', learning_rate=0.0001)
checkpoints = call('/object_info/CheckpointLoaderSimple')['CheckpointLoaderSimple']['input']['required']['ckpt_name'][0]
checkpoint = next((c for c in checkpoints if 'orangemix' in c.lower()), None)
if checkpoint is None:
    raise SystemExit('Expected existing SD1.5 OrangeMix checkpoint, not downloading anything.')
prefix = 'hardware-validation/synthetic-not-for-use-' + uuid.uuid4().hex[:12]
graph = {
    '1': {'class_type': 'CheckpointLoaderSimple', 'inputs': {'ckpt_name': checkpoint}},
    '2': {'class_type': 'CLIPTextEncode', 'inputs': {'clip': ['1', 1], 'text': 'a flower'}},
    '3': {'class_type': 'EmptyLatentImage', 'inputs': {'width': 64, 'height': 64, 'batch_size': 1}},
    '4': {'class_type': 'TrainLoraNode', 'inputs': inputs},
    '5': {'class_type': 'SaveLoRA', 'inputs': {'lora': ['4', 0], 'steps': ['4', 2], 'prefix': prefix}},
}
result = call('/prompt', {'prompt': graph, 'client_id': str(uuid.uuid4())})
prompt_id = result['prompt_id']
print(json.dumps({'prompt_id': prompt_id, 'prefix': prefix, 'checkpoint': checkpoint, 'dtype':dtype}), flush=True)
for _ in range(max(1, (args.timeout + 4) // 5)):
    history = call('/history/' + prompt_id)
    if prompt_id in history:
        item = history[prompt_id]
        status = item['status']
        errors = [detail.get('exception_message') for event, detail in status['messages'] if event == 'execution_error']
        print(json.dumps({'status':status['status_str'],'completed':status['completed'],'errors':errors}, ensure_ascii=False), flush=True)
        print(json.dumps(item.get('outputs', {}), ensure_ascii=False), flush=True)
        raise SystemExit(0 if item['status']['status_str'] == 'success' else 1)
    time.sleep(5)
raise SystemExit('Timed out waiting; inspect this prompt ID. No unrelated job was interrupted.')
