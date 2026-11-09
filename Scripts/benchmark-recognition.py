#!/usr/bin/env python3
"""Classifier-only physical-photo benchmark. Manual corners; not Apple Vision/Core ML accuracy."""
import argparse, hashlib, json
from pathlib import Path
import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
LABELS = np.array(['B','K','N','P','Q','R','empty','b','k','n','p','q','r'])
CORNERS = [
 [[.104,.067],[.779,.033],[.790,.936],[.125,.936]],
 [[.110,.071],[.708,.065],[.708,.912],[.088,.873]],
 [[.108,.044],[.800,.022],[.806,.975],[.106,.961]],
 [[.063,.143],[.891,.153],[.934,.777],[.028,.779]],
 [[.161,.156],[.820,.119],[.870,.797],[.180,.840]],
]
def uncertain(probs):
    order = np.sort(probs, axis=1)
    return (order[:,-1] < .85) | (order[:,-1] - order[:,-2] < .25) | (np.minimum(probs[:,0],probs[:,1]) > .15) | (np.minimum(probs[:,7],probs[:,8]) > .15)
def needs_verifier(probs):
    return uncertain(probs) | np.isin(probs.argmax(axis=1), [0,1,6,7,8])
def infer(session, inputs, dense=False):
    if dense:
        inputs = (inputs / 255 - np.array([.485,.456,.406],np.float32)) / np.array([.229,.224,.225],np.float32)
    else: inputs = inputs / 127.5 - 1
    views = []
    for k in range(4):
        rotated = np.rot90(inputs,k,axes=(1,2)).copy()
        views.append(np.concatenate([session.run(None,{session.get_inputs()[0].name:rotated[i:i+4]})[0] for i in range(0,len(inputs),4)]))
    return np.mean(views,axis=0)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('fixtures',type=Path);parser.add_argument('--output',type=Path,default=ROOT/'Documentation/recognition-benchmark.json');args=parser.parse_args()
    mobile_path=ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx'
    detail_path=ROOT/'Vendor/LiveChess2FEN/DenseNet201_last.onnx'
    mobile=ort.InferenceSession(str(mobile_path),providers=['CPUExecutionProvider'])
    detail=ort.InferenceSession(str(detail_path),providers=['CPUExecutionProvider'])
    truth=(args.fixtures/'boards.fen').read_text().strip().splitlines()
    reports=[];fusion_fixtures=[]
    for n,(line,corners) in enumerate(zip(truth,CORNERS),1):
        actual=[]
        for ch in line.split()[0]:
            if ch!='/':actual.extend(['empty']*int(ch) if ch.isdigit() else [ch])
        # Raw-photo orientations differ from the upstream detector's rotated-crop metadata.
        board=np.rot90(np.array(actual).reshape(8,8),[1,0,1,-1,2][n-1]).reshape(64)
        image=np.array(Image.open(args.fixtures/f'test{n}.jpg').convert('RGB'));h,w=image.shape[:2]
        warp=cv2.warpPerspective(image,cv2.getPerspectiveTransform((np.array(corners,np.float32)*[w,h]).astype(np.float32),np.array([[0,0],[1200,0],[1200,1200],[0,1200]],np.float32)),(1200,1200))
        tiles=[Image.fromarray(warp[(i//8)*150:(i//8+1)*150,(i%8)*150:(i%8+1)*150]).resize((224,224),Image.Resampling.NEAREST) for i in range(64)]
        inputs=np.stack([np.asarray(tile,dtype=np.float32) for tile in tiles])
        primary=infer(mobile,inputs);verify=needs_verifier(primary)
        indices=np.flatnonzero(verify)
        if n==1:indices=np.unique(np.concatenate([indices,[0,9,27]]))
        secondary=np.zeros_like(primary);secondary[indices]=infer(detail,inputs[indices],dense=True)
        probabilities=primary.copy();probabilities[verify]=(primary[verify]+secondary[verify])/2
        predicted=LABELS[probabilities.argmax(axis=1)]
        flagged=uncertain(probabilities) | (verify & (primary.argmax(axis=1)!=secondary.argmax(axis=1)))
        correct=predicted==board;kings=np.isin(board,['K','k'])
        reports.append({'photo':f'test{n}.jpg','correct_squares':int(correct.sum()),'total_squares':64,'exact_position':bool(correct.all()),'uncertain_squares':int(flagged.sum()),'confident_errors':int((~correct & ~flagged).sum()),'missed_pieces':int(((predicted=='empty')&(board!='empty')).sum()),'correct_kings':int(correct[kings].sum()),'total_kings':int(kings.sum()),'secondary_checks':int(verify.sum()),'manually_annotated_corners':corners})
        for i in range(64):
            fusion_fixtures.append({'primary':dict(zip(LABELS.tolist(),map(float,primary[i]))),'verifier':dict(zip(LABELS.tolist(),map(float,secondary[i]))) if verify[i] else None,'needsVerifier':bool(verify[i]),'label':str(predicted[i]),'confidence':float(probabilities[i].max()),'uncertain':bool(flagged[i])})
        if n==1:
            target=ROOT/'Tests/Fixtures';target.mkdir(exist_ok=True);refs=[]
            for index in [0,9,27]:
                tiles[index].save(target/f'square-{index}.png')
                for model,probs in [('ChessPieces',primary),('ChessPiecesDetail',secondary)]:
                    refs.append({'image':f'square-{index}.png','model':model,'probabilities':dict(zip(LABELS.tolist(),map(float,probs[index])))})
            (target/'reference.json').write_text(json.dumps(refs,indent=2)+'\n')
        print('Completed physical photo',n,flush=True)
    result={'scope':'Five upstream physical-board photographs with manually annotated corners and orientation. Not an independent held-out set or end-to-end iPhone/Core ML accuracy.','inference':'Four-view MobileNetV2; four-view DenseNet201 second opinion for uncertainty, kings, bishops and apparent empties. Mean probabilities when verified; disagreements remain flagged.','primary_sha256':hashlib.sha256(mobile_path.read_bytes()).hexdigest(),'verifier_sha256':hashlib.sha256(detail_path.read_bytes()).hexdigest(),'correct_squares':sum(p['correct_squares'] for p in reports),'total_squares':320,'square_accuracy':sum(p['correct_squares'] for p in reports)/320,'exact_positions':sum(p['exact_position'] for p in reports),'total_positions':5,'uncertain_squares':sum(p['uncertain_squares'] for p in reports),'missed_pieces':sum(p['missed_pieces'] for p in reports),'correct_kings':sum(p['correct_kings'] for p in reports),'total_kings':sum(p['total_kings'] for p in reports),'photos':reports}
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    (ROOT/'Tests/Core/Reference/recognition.json').write_text(json.dumps(fusion_fixtures,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
