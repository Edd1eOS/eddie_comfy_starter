"""Small local generation acceptance probe; installs no nodes or models."""
import argparse
import json
import time
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8188)
parser.add_argument('--size', type=int, default=512)
parser.add_argument('--steps', type=int, default=12)
parser.add_argument('--timeout', type=int, default=300)
args = parser.parse_args()
base = f'http://127.0.0.1:{args.port}'
def call(path, payload=None):
    req = urllib.request.Request(base + path, data=None if payload is None else json.dumps(payload).encode(),
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)
queue = call('/queue')
if queue['queue_running'] or queue['queue_pending']:
    raise SystemExit('Busy queue; no test submitted.')
choices = call('/object_info/CheckpointLoaderSimple')['CheckpointLoaderSimple']['input']['required']['ckpt_name'][0]
checkpoint = next((c for c in choices if 'orangemix' in c.lower()), None)
if checkpoint is None:
    raise SystemExit('Existing OrangeMix checkpoint required; no download performed.')
prefix = 'hardware-validation/generation-' + uuid.uuid4().hex[:12]
graph = {
    '1': {'class_type':'CheckpointLoaderSimple','inputs':{'ckpt_name':checkpoint}},
    '2': {'class_type':'CLIPTextEncode','inputs':{'clip':['1',1],'text':'a single white daisy in a small blue ceramic vase on a wooden table, daylight, detailed illustration'}},
    '3': {'class_type':'CLIPTextEncode','inputs':{'clip':['1',1],'text':'blurry, low quality, text, watermark'}},
    '4': {'class_type':'EmptyLatentImage','inputs':{'width':args.size,'height':args.size,'batch_size':1}},
    '5': {'class_type':'KSampler','inputs':{'model':['1',0],'positive':['2',0],'negative':['3',0],'latent_image':['4',0],
          'seed':42,'steps':args.steps,'cfg':6.0,'sampler_name':'euler','scheduler':'normal','denoise':1.0}},
    '6': {'class_type':'VAEDecode','inputs':{'samples':['5',0],'vae':['1',2]}},
    '7': {'class_type':'SaveImage','inputs':{'images':['6',0],'filename_prefix':prefix}},
}
result = call('/prompt', {'prompt':graph,'client_id':str(uuid.uuid4())})
prompt_id = result['prompt_id']
print(json.dumps({'prompt_id':prompt_id,'prefix':prefix}), flush=True)
for _ in range(max(1, (args.timeout + 4) // 5)):
    item = call('/history/' + prompt_id).get(prompt_id)
    if item:
        print(json.dumps({'status':item['status'],'outputs':item.get('outputs',{})},ensure_ascii=False),flush=True)
        raise SystemExit(0 if item['status']['status_str'] == 'success' else 1)
    time.sleep(5)
raise SystemExit('Timed out; inspect this prompt ID. No unrelated job was interrupted.')
