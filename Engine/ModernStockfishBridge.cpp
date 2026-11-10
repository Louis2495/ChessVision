// Official Stockfish is namespace-isolated at compile time from Fairy-Stockfish.
#include "StockfishBridge.h"
#include "../Vendor/Stockfish19/src/engine.h"
#include "../Vendor/Stockfish19/src/bitboard.h"
#include "../Vendor/Stockfish19/src/position.h"
#include "../Vendor/Stockfish19/src/uci.h"
#include "../Vendor/Stockfish19/src/tune.h"
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>
#include <sstream>
#include <stdexcept>

namespace {
std::mutex mutex;
std::condition_variable wake;
std::deque<std::string> commands;
std::once_flag once;
CVEngineCallback callback = nullptr;
void emit(const std::string& line) { if (callback) callback(line.c_str()); }
}
extern "C" void cv_modern_start(CVEngineCallback listener, const char* networkPath) {
    const std::string path = networkPath ? networkPath : "";
    std::call_once(once, [listener, path] {
        callback = listener;
        std::thread([path] {
            try {
                using namespace Stockfish;
                Attacks::init(); Position::init();
                auto engine = std::make_unique<Engine>();
                engine->set_on_verify_network([](std::string_view message) {
                    // Upstream exits on a missing net. Throw from its verification callback
                    // before that exit so a corrupt installation cannot terminate the app.
                    if (message.find("ERROR:") != std::string_view::npos)
                        throw std::runtime_error("Stockfish 19 neural network could not be loaded. Reinstall the app.");
                });
                std::istringstream netOption("name EvalFile value " + path);
                engine->get_options().setoption(netOption);
                engine->verify_network();
                engine->set_on_start([] {});
                engine->set_on_iter([](const Engine::InfoIter&) {});
                engine->set_on_update_no_moves([](const Engine::InfoShort& info) {
                    emit("info depth " + std::to_string(info.depth) + " score " + UCIEngine::format_score(info.score));
                });
                engine->set_on_update_full([](const Engine::InfoFull& info) {
                    std::ostringstream line;
                    line << "info depth " << info.depth << " seldepth " << info.selDepth
                         << " multipv " << info.multiPV << " score " << UCIEngine::format_score(info.score);
                    if (!info.bound.empty()) line << " " << info.bound;
                    line << " nodes " << info.nodes << " nps " << info.nps << " time " << info.timeMs << " pv " << info.pv;
                    emit(line.str());
                });
                engine->set_on_bestmove([](std::string_view move, std::string_view ponder) {
                    emit("bestmove " + std::string(move) + (ponder.empty() ? "" : " ponder " + std::string(ponder)));
                });
                Tune::init(engine->get_options());
                for (;;) {
                    std::string command;
                    { std::unique_lock<std::mutex> lock(mutex); wake.wait(lock, [] { return !commands.empty(); }); command = std::move(commands.front()); commands.pop_front(); }
                    std::istringstream stream(command); std::string token; stream >> token;
                    if (token == "uci") { emit("id name Stockfish 19 NNUE"); emit("uciok"); }
                    else if (token == "isready") emit("readyok");
                    else if (token == "stop") engine->stop();
                    else if (token == "setoption") { engine->wait_for_search_finished(); engine->get_options().setoption(stream); }
                    else if (token == "ucinewgame") { engine->wait_for_search_finished(); engine->search_clear(); }
                    else if (token == "position") {
                        engine->wait_for_search_finished(); stream >> token;
                        std::string fen;
                        if (token == "startpos") { fen = StartFEN; stream >> token; }
                        else if (token == "fen") { while (stream >> token && token != "moves") fen += token + " "; }
                        std::vector<std::string> moves; while (stream >> token) moves.push_back(token);
                        if (engine->set_position(fen, moves)) throw std::runtime_error("Stockfish rejected this position.");
                    } else if (token == "go") {
                        Search::LimitsType limits; limits.startTime = now();
                        while (stream >> token) {
                            if (token == "infinite") limits.infinite = 1;
                            else if (token == "movetime") stream >> limits.movetime;
                            else if (token == "depth") stream >> limits.depth;
                            else if (token == "nodes") stream >> limits.nodes;
                        }
                        engine->go(limits);
                    }
                }
            } catch (const std::exception& error) { emit(std::string("engineerror ") + error.what()); }
        }).detach();
    });
}
extern "C" void cv_modern_send(const char* command) {
    if (!command) return;
    { std::lock_guard<std::mutex> lock(mutex); commands.emplace_back(command); }
    wake.notify_one();
}
