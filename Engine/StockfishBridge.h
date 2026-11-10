#ifndef CHESSVISION_STOCKFISH_BRIDGE_H
#define CHESSVISION_STOCKFISH_BRIDGE_H
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*CVEngineCallback)(const char *line);
void cv_engine_start(CVEngineCallback callback);
void cv_engine_send(const char *command);
char* cv_rules_query(const char *variant, const char *history);
char* cv_bughouse_query(const char *fen, const char *move);
void cv_rules_free(char *text);
#ifdef __cplusplus
}
#endif
#endif
