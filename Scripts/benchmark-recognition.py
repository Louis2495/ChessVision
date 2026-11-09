#!/usr/bin/env python3
"""Classifier-only benchmark on upstream physical-board photos with manually annotated corners.
This does NOT exercise Apple Vision board detection or the converted Core ML runtime.
"""
import argparse, hashlib, json
from pathlib import Path
import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
LABELS=np.array(['B','K','N','P','Q','R','empty','b','k','n','p','q','r'])
# Normalized image coordinates of the PLAYING area, TL/TR/BR/BL (manual annotation).
CORNERS=[
 [[.104,.067],[.779,.033],[.790,.936],[.125,.936]],
 [[.110,.071],[.708,.065],[.708,.912],[.088,.873]],
 [[.108,.044],[.800,.022],[.806,.975],[.106,.961]],
 [[.063,.143],[.891,.153],[.934,.777],[.028,.779]],
 [[.161,.156],[.820,.119],[.870,.797],[.180,.840]],
]
def main():
 p=argparse.ArgumentParser();p.add_argument('fixtures',type=Path,help='TestImages/FullDetection extracted from upstream TestImages.zip');p.add_argument('--output',type=Path,default=ROOT/'Documentation/recognition-benchmark.json');a=p.parse_args()
 sess=ort.InferenceSession(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx'),providers=['CPUExecutionProvider'])
 truth=(a.fixtures/'boards.fen').read_text().strip().splitlines();reports=[];all_correct=0;total_uncertain=0
 for n,(line,corners) in enumerate(zip(truth,CORNERS),1):
  fen,orientation=line.split();actual=[]
  for ch in fen:
   if ch=='/':continue
   actual.extend(['empty']*int(ch) if ch.isdigit() else [ch])
  board=np.array(actual).reshape(8,8)
  # Reference orientation describes a1's location in the raw image.
  # Annotated raw-photo orientation; upstream metadata is for its detector's rotated crop.
  board=np.rot90(board,[1,0,1,-1,2][n-1])
  image=np.array(Image.open(a.fixtures/f'test{n}.jpg').convert('RGB'));h,w=image.shape[:2]
  src=np.array(corners,dtype=np.float32)*[w,h]
  warp=cv2.warpPerspective(image,cv2.getPerspectiveTransform(src.astype(np.float32),np.array([[0,0],[1200,0],[1200,1200],[0,1200]],np.float32)),(1200,1200))
  batch=[]
  for row in range(8):
   for col in range(8):
    tile=Image.fromarray(warp[row*150:(row+1)*150,col*150:(col+1)*150]).resize((224,224),Image.Resampling.NEAREST)
    batch.append(np.asarray(tile,dtype=np.float32)/127.5-1)
  inputs=np.stack(batch)
  rotated=[]
  for k in range(4):
   v=np.rot90(inputs,k,axes=(1,2)).copy()
   rotated.append(np.concatenate([sess.run(None,{sess.get_inputs()[0].name:v[i:i+8]})[0] for i in range(0,64,8)]))
  probs=np.mean(rotated,axis=0)
  predicted=LABELS[probs.argmax(axis=1)].reshape(8,8);correct=int(np.sum(predicted==board));all_correct+=correct
  sorted_probs=np.sort(probs,axis=1);uncertain=(sorted_probs[:,-1]<.85)|(sorted_probs[:,-1]-sorted_probs[:,-2]<.25);total_uncertain+=int(uncertain.sum())
  reports.append({'photo':f'test{n}.jpg','correct_squares':correct,'total_squares':64,'exact_position':correct==64,'uncertain_squares':int(uncertain.sum()),'confident_errors':int(((predicted!=board).reshape(64)&~uncertain).sum()),'manually_annotated_corners':corners})
  if n==1:
   target=ROOT/'Tests/Fixtures';target.mkdir(exist_ok=True)
   refs=[]
   for index in [0,9,27]:
    tile=Image.fromarray(warp[(index//8)*150:(index//8+1)*150,(index%8)*150:(index%8+1)*150]).resize((224,224),Image.Resampling.NEAREST)
    tile.save(target/f'square-{index}.png');refs.append({'image':f'square-{index}.png','probabilities':dict(zip(LABELS.tolist(),map(float,probs[index])))})
   (target/'reference.json').write_text(json.dumps(refs,indent=2)+'\n')
 result={'scope':'ONNX classifier on five upstream physical-board photographs, using manual playing-area corners. Not iPhone/Core ML/end-to-end accuracy. These are upstream example photos, not an independent held-out dataset.','inference':'Mean probabilities of four 90-degree rotations per square; MobileNetV2 full width','model_sha256':hashlib.sha256((ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx').read_bytes()).hexdigest(),'correct_squares':all_correct,'total_squares':320,'square_accuracy':all_correct/320,'exact_positions':sum(r['exact_position'] for r in reports),'total_positions':5,'uncertain_squares':total_uncertain,'photos':reports}
 a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
