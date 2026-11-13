# Estimated App Store size

For the current iPhone build, budget **150–180 MB download** and **190–230 MB installed**, excluding user photos, game history and other growing app data. These are engineering estimates, not an App Store Connect size report. A signed Release archive is needed to measure Core ML compilation, asset-catalog output, executable size, encryption and device thinning.

Measured source resources (decimal MB), with ordinary per-file DEFLATE compression as an approximation:

| Group | Uncompressed | Compressed approximation |
| --- | ---: | ---: |
| Stockfish 19 NNUE | 98.51 MB | 78.94 MB |
| Two recognition models | 48.13 MB | 43.59 MB |
| Piano soundtrack | 17.64 MB | 13.71 MB |
| Artwork, puzzles, openings, map | 5.47 MB | 2.75 MB |
| **Asset total** | **169.75 MB** | **138.99 MB** |

The estimate adds allowance for the compiled app/engines and resource conversion. Apple system frameworks are supplied by iOS. Developer source, test fixtures and debugging symbols are not part of the normal App Store download. Confirm the final download/installed sizes in Xcode's app-thinning report and App Store Connect after uploading an archive.
