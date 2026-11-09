# Recognition implementation and evidence

## Chosen implementation

Camera → orientation-normalized RGB image (maximum 2048px on its longest side) → Apple Vision rectangular candidates → perspective correction → periodic 8×8 grid refinement → 64 square images → bundled Core ML classifier → position plus uncertainty flags.

`BoardGrid` seeks seven regularly spaced internal edges in both axes. It rejects blank rectangles and tries to remove the outer decorative border. The user must still verify the crop. Rectangle/grid detection is a heuristic, has not been run through Apple's frameworks here, and may reject a valid board or select the wrong rectangle. Detection currently tries the largest complete rectangular candidate; it does not search every candidate after a grid rejection.

The actual piece model is LiveChess2FEN **MobileNetV2 full width**, not a generic Vision image classifier. It distinguishes 12 pieces plus empty. See `Vendor/LiveChess2FEN/PROVENANCE.json` for the pinned release, source code revision, labels and SHA-256. The original ONNX graph/weights and upstream training scripts accompany the converted artifact. All 64 squares are classified independently; the app does not force counts, assume a starting position, or secretly rewrite pieces to make FEN legal.

Inference averages four 90-degree rotations of each square. The Core ML model includes the ensemble and RGB `pixel/127.5 - 1` normalization, so the Swift side passes unnormalized images with `scaleFill`. Predictions below 0.85 confidence or below 0.25 top-two margin are marked uncertain. These thresholds are heuristics, not calibrated probabilities. Users must review all pieces, including confident predictions, before analysis.

Photo orientation is not inferred from piece placement. Capture guidance asks for White at the bottom; the editor supports quarter-turn rotation. Side to move, castling rights, en passant and counters are separate explicit state; castling is off for recognized photos by default.

## Model research and comparison

Apple Vision provides rectangles and a Core ML inference interface, but no built-in chess-piece recognizer. LiveChess2FEN provides physical-board models with an explicit AGPL license. Its published model assets were obtainable without credentials or a paid API. Its Python board detector is not shipped in the iPhone app; Apple's frameworks and the portable grid fitter replace that component.

On the same five upstream physical-board photos, manually cropped to the playing area:

| Candidate | Correct squares | Exact positions | Confident errors at current thresholds |
| --- | ---: | ---: | ---: |
| MobileNetV2 width 0.35, single view | 254/320 | 0/5 | Not used as a calibrated baseline |
| MobileNetV2 full width, single view | 281/320 | 0/5 | 22 |
| DenseNet201, single view | 288/320 | 0/5 | 20 |
| **MobileNetV2 full width, four views (bundled)** | **287/320 (89.6875%)** | **0/5** | **0 on these examples** |

The chosen ensemble catches more mistakes as uncertainty on these samples and uses a substantially smaller weight file than DenseNet201. It flagged 76/320 squares for review, including all 33 mistakes. This is not a guarantee that future errors will be flagged. Performance and battery usage on an actual iPhone are unmeasured.

These are **upstream example photographs, not independent held-out data**. Corners and raw-photo orientations were manually annotated for the classifier experiment. The upstream FEN orientation annotations describe its own detector's crop, which can be rotated relative to the raw JPEG; this benchmark records the raw orientations separately. The benchmark bypasses Apple Vision and Core ML and cannot establish end-to-end iPhone accuracy. It contains no verified standard-starting-position or sparse-endgame test set, and limited variation in boards/pieces/lighting. Reliable automatic recognition remains an unmet acceptance criterion.

## Reproduce conversion (optional; not needed for an Xcode build)

Use Python 3.12 in a virtual environment. On Linux, installing CPU-only PyTorch first avoids downloading CUDA components:

```sh
python3 -m venv .build/model-tools
source .build/model-tools/bin/activate
pip install --index-url https://download.pytorch.org/whl/cpu torch==2.5.1 torchvision==0.20.1
pip install -r Scripts/model-requirements.txt
python Scripts/convert-model.py
```

On a Mac use the normal PyPI PyTorch wheels instead of the Linux CPU index. The script checks ONNX-versus-Torch numerical equivalence, checks the traced four-view graph, then writes `ChessPieces.mlpackage`. Fixed-size trace warnings are expected because the input is intentionally fixed at 224×224. Conversion on Linux emits a Core ML model but cannot run Apple's Core ML runtime. The hosted Xcode tests check real-photo fixture parity against ONNX, with a 0.025 probability tolerance for converted FP16 arithmetic; these tests still need to run on a Mac.

## Reproduce the photo benchmark

Download the public asset from `https://github.com/davidmallasen/LiveChess2FEN/releases/download/v0.1.0/TestImages.zip`. Its SHA-256 is `351b79ffe01d41578670854f8092f2228531871842c7d6341134ebc390495700`. Verify the checksum before extraction. Do not disable TLS or checksum verification.

With the model-tool environment active:

```sh
pip install opencv-python-headless==4.11.0.86
python Scripts/benchmark-recognition.py /path/to/TestImages/FullDetection
```

The current report is `Documentation/recognition-benchmark.json`. This rewrites the report and the three test-only photo-square parity fixtures, so rerun only when intentionally updating the model or benchmark. Original complete photos are downloaded for evaluation and are not packaged in the app. Three small public-photo crops are included in the test bundle with upstream notices.
