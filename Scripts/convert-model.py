from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
import onnx,torch,numpy as np,onnxruntime as ort,coremltools as ct
from onnx2torch import convert
m=onnx.load(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_0p35_all_last.onnx'))
print([(x.name,[d.dim_value for d in x.type.tensor_type.shape.dim]) for x in m.graph.input])
print([(x.name,[d.dim_value for d in x.type.tensor_type.shape.dim]) for x in m.graph.output])
net=convert(m).eval()
x=np.random.default_rng(42).uniform(-1,1,(1,224,224,3)).astype(np.float32)
a=ort.InferenceSession(str(ROOT/'Vendor/LiveChess2FEN/MobileNetV2_0p35_all_last.onnx'),providers=['CPUExecutionProvider']).run(None,{m.graph.input[0].name:x})[0]
with torch.no_grad(): b=net(torch.from_numpy(x)).numpy()
print('ONNX/Torch max difference',np.max(np.abs(a-b)))
np.testing.assert_allclose(a,b,atol=1e-4,rtol=1e-3)
class Wrapper(torch.nn.Module):
 def __init__(self):super().__init__();self.net=net
 def forward(self,x):return self.net(x.permute(0,2,3,1))
w=Wrapper().eval()
trace=torch.jit.trace(w,torch.zeros(1,3,224,224))
ml=ct.convert(trace,inputs=[ct.ImageType(name='image',shape=(1,3,224,224),scale=1/127.5,bias=[-1,-1,-1],color_layout=ct.colorlayout.RGB)],classifier_config=ct.ClassifierConfig(['B','K','N','P','Q','R','empty','b','k','n','p','q','r']),minimum_deployment_target=ct.target.iOS17,convert_to='mlprogram')
ml.author='David Mallasén Quintana et al. (LiveChess2FEN); Core ML conversion by ChessVision'
ml.license='AGPL-3.0-or-later; see Vendor/LiveChess2FEN/LICENSE'
ml.short_description='Physical chess-square classifier. Experimental; validate all reconstructed positions.'
ml.save(str(ROOT/'ChessVision/Resources/ChessPieces.mlpackage'))
