#include "StockfishBridge.h"
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <string>
#include <vector>
std::mutex m;
std::condition_variable cv;
std::vector<std::string> lines;
void receive(const char *line) { std::lock_guard<std::mutex> l(m); lines.emplace_back(line); cv.notify_all(); }
bool waitFor(const std::string &prefix) {
    std::unique_lock<std::mutex> l(m);
    return cv.wait_for(l, std::chrono::seconds(15), [&]{for(auto &s:lines) if(s.rfind(prefix,0)==0) return true; return false;});
}
int main() {
    cv_engine_start(receive); cv_engine_send("uci");
    if(!waitFor("uciok")) return 1;
    cv_engine_send("setoption name Threads value 1"); cv_engine_send("setoption name MultiPV value 3"); cv_engine_send("isready");
    if(!waitFor("readyok")) return 2;
    cv_engine_send("position startpos"); cv_engine_send("go depth 8");
    if(!waitFor("bestmove ")) return 3;
    { std::lock_guard<std::mutex> l(m); bool pv=false; for(auto &s:lines) if(s.find(" pv ")!=std::string::npos) pv=true; if(!pv) return 4; lines.clear(); }
    cv_engine_send("position fen 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"); cv_engine_send("go depth 2");
    if(!waitFor("bestmove (none)")) return 5;
    { std::lock_guard<std::mutex> l(m); lines.clear(); }
    cv_engine_send("position startpos"); cv_engine_send("go infinite");
    if(!waitFor("info depth 4")) return 6;
    cv_engine_send("stop"); if(!waitFor("bestmove ")) return 7;
    { std::lock_guard<std::mutex> l(m); lines.clear(); }
    cv_engine_send("position startpos"); cv_engine_send("go perft 3");
    if(!waitFor("Nodes searched: 8902")) return 8;
    std::puts("PASS: UCI handshake, MultiPV search, terminal position, cancellation, perft(3)=8902.");
    // The embedded engine intentionally lives for the process lifetime.
    std::fflush(stdout); std::_Exit(0);
}
