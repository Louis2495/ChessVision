#pragma once
// Separate all modern C++ symbols from the variant engine linked in the same app.
#define Stockfish CVStockfish19
#ifndef NNUE_EMBEDDING_OFF
#define NNUE_EMBEDDING_OFF 1
#endif
#ifdef NO_PREFETCH
#undef NO_PREFETCH
#endif
#if defined(__aarch64__) || defined(__arm64__)
#define USE_NEON 8
#elif defined(__SSE2__)
#define USE_SSE2 1
#endif
