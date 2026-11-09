from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
import onnx,torch,numpy as np,onnxruntime as ort,coremltools as ct
from onnx2torch import convert
m=onnx.load(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx'))
print([(x.name,[d.dim_value for d in x.type.tensor_type.shape.dim]) for x in m.graph.input])
print([(x.name,[d.dim_value for d in x.type.tensor_type.shape.dim]) for x in m.graph.output])
net=convert(m).eval()
x=np.random.default_rng(42).uniform(-1,1,(1,224,224,3)).astype(np.float32)
a=ort.InferenceSession(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx'),providers=['CPUExecutionProvider']).run(None,{m.graph.input[0].name:x})[0]
with torch.no_grad(): b=net(torch.from_numpy(x)).numpy()
print('ONNX/Torch max difference',np.max(np.abs(a-b)))
np.testing.assert_allclose(a,b,atol=1e-4,rtol=1e-3)
class Wrapper(torch.nn.Module):
 def __init__(self):super().__init__();self.net=net
 def forward(self,x):
  # Four rotations make square classification less sensitive to piece facing.
  views=torch.cat([x,x.transpose(2,3).flip(2),x.flip(2,3),x.transpose(2,3).flip(3)],dim=0)
  return self.net(views.permute(0,2,3,1)).mean(dim=0,keepdim=True)
w=Wrapper().eval()
trace=torch.jit.trace(w,torch.zeros(1,3,224,224))
# Check the fixed-shape, four-rotation traced graph against the original ONNX model.
session=ort.InferenceSession(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx'),providers=['CPUExecutionProvider'])
rotated=[session.run(None,{m.graph.input[0].name:np.rot90(x,k,axes=(1,2)).copy()})[0] for k in range(4)]
with torch.no_grad(): traced=trace(torch.from_numpy(x.transpose(0,3,1,2).copy())).numpy()
np.testing.assert_allclose(np.mean(rotated,axis=0),traced,atol=1e-4,rtol=1e-3)
print('Four-rotation ONNX/traced Torch parity passed')
ml=ct.convert(trace,inputs=[ct.ImageType(name='image',shape=(1,3,224,224),scale=1/127.5,bias=[-1,-1,-1],color_layout=ct.colorlayout.RGB)],classifier_config=ct.ClassifierConfig(['B','K','N','P','Q','R','empty','b','k','n','p','q','r']),minimum_deployment_target=ct.target.iOS17,convert_to='mlprogram')
ml.author='David Mallasén Quintana et al. (LiveChess2FEN); Core ML conversion by ChessVision'
ml.license='AGPL-3.0-or-later; see Vendor/LiveChess2FEN/LICENSE'
ml.short_description='Physical chess-square classifier, four-rotation ensemble. Experimental; review every square.'
import hashlib
ml.user_defined_metadata['sourceSHA256']=hashlib.sha256((ROOT/'Vendor/LiveChess2FEN/MobileNetV2_all_last.onnx').read_bytes()).hexdigest()
ml.user_defined_metadata['inference']='Mean probabilities of four quarter-turn views per square.'
ml.save(str(ROOT/'ChessVision/Resources/ChessPieces.mlpackage'))
