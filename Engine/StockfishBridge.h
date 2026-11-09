#ifndef CHESSVISION_STOCKFISH_BRIDGE_H
#define CHESSVISION_STOCKFISH_BRIDGE_H
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*CVEngineCallback)(const char *line);
void cv_engine_start(CVEngineCallback callback);
void cv_engine_send(const char *command);
#ifdef __cplusplus
}
#endif
#endif
