# Recognition implementation and evidence

## Updated pipeline

Camera → normalized RGB image → all complete Apple Vision rectangle candidates → perspective correction and repeating-grid validation → best grid candidate → 64 square crops → MobileNetV2 primary classifier → DenseNet201 verification when needed → position with optional orange hints.

The detector now checks **every** complete rectangle, rather than assuming that the largest rectangle is the playing area. Grid quality and board area choose among candidates; a table edge with no valid grid no longer prevents trying a smaller board. This detector is still heuristic and has not been exercised through Apple Vision on this Linux machine.

Both classifiers are actual pretrained physical-piece models from LiveChess2FEN v0.1.0. They recognize all twelve pieces plus empty. Each averages four quarter-turn views. The primary uses RGB/127.5−1; the verifier uses ImageNet RGB/255 mean/std normalization. Preprocessing is embedded in the Core ML models. Sources, hashes, labels and training scripts are in `Vendor/LiveChess2FEN`.

A secondary check runs for:

- Low-confidence predictions (less than 0.85 confidence or less than 0.25 top-two margin).
- Every apparently empty square, so potentially missed pieces receive another opinion.
- Every king/bishop prediction, including confident ones, addressing the reported king-versus-bishop confusion.

When verified, class probabilities are averaged. Model disagreement, low fused confidence and king/bishop ambiguity remain highlighted. The algorithm does **not** force a king onto an empty square, assume a starting position, or silently change pieces to make a position legal. Model scores are uncalibrated; orange hints can miss errors on unseen boards.

Orange squares do not block analysis. The user can analyze any structurally valid position immediately after choosing the side to move. Invalid or missing kings and other FEN inconsistencies still block Stockfish safely. The crop-confirmation, turn-confirmation and full-review toggles, rotate control and fixed analysis-time menu were removed as requested. Recognition shows per-square progress and can be canceled.

## Measured comparison

Same five public upstream physical-board photographs, with manual playing-area corners and raw-photo orientation:

| Pipeline | Correct squares | Exact positions | Uncertain squares |
| --- | ---: | ---: | ---: |
| Previous MobileNetV2 four-view model | 287/320 (89.6875%) | 0/5 | 76 |
| Updated selective MobileNetV2 + DenseNet201 verification | **296/320 (92.5%)** | **0/5** | **64** |

All 24 remaining mistakes were highlighted in this small benchmark; no confident errors remained. This is not a guarantee for new photos. Seven of ten kings were correct, so **king confusion is still unresolved**. No occupied square was predicted empty on these examples, both before and after; this set cannot demonstrate improvement for the user's missed-piece examples. We do not have those original photos or their ground truth.

The updated classifier checked 265/320 squares with the secondary model. This adds computation, memory and approximately 39 MiB of compiled model weights; full-board latency, memory, thermal behavior and battery use need measurement on an iPhone. No speed claim is made.

These are upstream example images, not an independent held-out set. The benchmark bypasses Apple Vision and Core ML, manually annotates corners/orientation, and contains limited physical styles and lighting. It does not cover a confirmed starting-position or sparse-endgame set. **Reliable, completely automatic position reconstruction remains an unmet acceptance criterion.** Details are in `recognition-benchmark.json`, including per-photo king and missed-piece counts.

## Reproducibility

Xcode builds use the checked-in model packages and require no Python, network access or model conversion. For optional model work, use Python 3.12:

```sh
python3 -m venv .build/model-tools
source .build/model-tools/bin/activate
# Linux CPU wheels; on a Mac use the standard PyPI PyTorch wheels instead.
pip install --index-url https://download.pytorch.org/whl/cpu torch==2.5.1 torchvision==0.20.1
pip install -r Scripts/model-requirements.txt
python Scripts/convert-model.py
python Scripts/convert-detail-model.py
```

Both scripts compare original ONNX results with the traced Torch graphs before Core ML conversion. Fixed-input trace warnings and Linux warnings about the unavailable Apple runtime are expected. Neither conversion success nor ONNX parity establishes Core ML runtime correctness. Hosted Mac tests exercise both actual converted artifacts against six per-model photo-square references.

Download upstream `https://github.com/davidmallasen/LiveChess2FEN/releases/download/v0.1.0/TestImages.zip` and verify SHA-256 `351b79ffe01d41578670854f8092f2228531871842c7d6341134ebc390495700` before extraction. Keep TLS and checksum verification enabled.

```sh
pip install opencv-python-headless==4.11.0.86
python Scripts/benchmark-recognition.py /path/to/TestImages/FullDetection
```

The benchmark rewrites the report, six native model references (three public photo crops × two models), and 320 portable fusion regression cases. Do this only when deliberately updating recognition. Complete source photos are not packaged in the app; small public-photo crops live only in the test bundle.
