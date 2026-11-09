#!/usr/bin/env python3
"""Convert the pinned DenseNet201 verifier; the normal Xcode build needs no Python."""
from pathlib import Path
import hashlib
import coremltools as ct
import numpy as np
import onnx
import onnxruntime as ort
from onnx2torch import convert
import torch
ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'Vendor/LiveChess2FEN/DenseNet201_last.onnx'
EXPECTED_SHA256 = '53fec7ea8fe1dfb7e18af0f3252c8835efab29dbb51c070365083fe1fe34c7f6'
assert hashlib.sha256(source.read_bytes()).hexdigest() == EXPECTED_SHA256, 'Unexpected verifier source weights'
graph = onnx.load(str(source))
network = convert(graph).eval()
class DetailClassifier(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.network = network
        self.register_buffer('mean', torch.tensor([.485, .456, .406]).reshape(1, 3, 1, 1))
        self.register_buffer('std', torch.tensor([.229, .224, .225]).reshape(1, 3, 1, 1))
    def forward(self, image):
        normalized = (image - self.mean) / self.std
        views = torch.cat([normalized, normalized.transpose(2, 3).flip(2), normalized.flip(2, 3), normalized.transpose(2, 3).flip(3)], dim=0)
        return self.network(views.permute(0, 2, 3, 1)).mean(dim=0, keepdim=True)
classifier = DetailClassifier().eval()
trace = torch.jit.trace(classifier, torch.zeros(1, 3, 224, 224))
rgb = np.random.default_rng(42).uniform(0, 1, (1, 224, 224, 3)).astype(np.float32)
normalized = (rgb - np.array([.485, .456, .406], np.float32)) / np.array([.229, .224, .225], np.float32)
session = ort.InferenceSession(str(source), providers=['CPUExecutionProvider'])
reference = np.mean([session.run(None, {graph.graph.input[0].name: np.rot90(normalized, k, axes=(1, 2)).copy()})[0] for k in range(4)], axis=0)
with torch.no_grad():
    prediction = trace(torch.from_numpy(rgb.transpose(0, 3, 1, 2).copy())).numpy()
np.testing.assert_allclose(prediction, reference, atol=1e-4, rtol=1e-3)
print('DenseNet ONNX/traced Torch parity passed; max error:', float(np.max(np.abs(prediction-reference))))
model = ct.convert(trace, inputs=[ct.ImageType(name='image', shape=(1, 3, 224, 224), scale=1/255, color_layout=ct.colorlayout.RGB)], classifier_config=ct.ClassifierConfig(['B','K','N','P','Q','R','empty','b','k','n','p','q','r']), minimum_deployment_target=ct.target.iOS17, convert_to='mlprogram')
model.author = 'David Mallasén Quintana et al. (LiveChess2FEN); conversion by ChessVision'
model.license = 'AGPL-3.0-or-later; see Vendor/LiveChess2FEN/LICENSE'
model.short_description = 'Second opinion for ambiguous or apparently empty physical chessboard squares.'
model.user_defined_metadata['sourceSHA256'] = EXPECTED_SHA256
model.user_defined_metadata['inference'] = 'DenseNet201, four quarter-turn views, RGB/255 normalized by ImageNet mean/std.'
model.save(str(ROOT / 'ChessVision/Resources/ChessPiecesDetail.mlpackage'))
