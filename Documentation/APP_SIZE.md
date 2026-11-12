# Estimated App Store size

For the current iPhone build, budget **140–170 MB download** and **180–220 MB installed**, excluding user photos, game history and other growing app data. These are engineering estimates, not an App Store Connect size report. A signed Release archive is needed to measure Core ML compilation, asset-catalog output, executable size, encryption and device thinning.

Measured source resources (decimal MB), with ordinary per-file DEFLATE compression as an approximation:

| Group | Uncompressed | Compressed approximation |
| --- | ---: | ---: |
| Stockfish 19 NNUE | 98.51 MB | 79.08 MB |
| Two recognition models | 48.13 MB | 43.61 MB |
| Piano soundtrack | 9.25 MB | 7.43 MB |
| Artwork, puzzles, openings, map | 5.45 MB | 2.74 MB |
| **Asset total** | **161.34 MB** | **132.86 MB** |

The estimate adds allowance for the compiled app/engines and resource conversion. Apple system frameworks are supplied by iOS. Developer source, test fixtures and debugging symbols are not part of the normal App Store download. Confirm the final download/installed sizes in Xcode's app-thinning report and App Store Connect after uploading an archive.
