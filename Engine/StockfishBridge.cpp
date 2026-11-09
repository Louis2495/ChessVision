#include "StockfishBridge.h"
#include <condition_variable>
#include <deque>
#include <iostream>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>
#include "bitboard.h"
#include "position.h"
#include "search.h"
#include "thread.h"
#include "uci.h"
#include "endgame.h"
namespace PSQT { void init(); }
namespace {
class InputBuffer : public std::streambuf {
    std::mutex mutex;
    std::condition_variable ready;
    std::deque<char> queue;
    char current = 0;
public:
    void send(const std::string &command) {
        { std::lock_guard<std::mutex> lock(mutex); for (char ch : command) queue.push_back(ch); queue.push_back('\n'); }
        ready.notify_one();
    }
    int_type underflow() override {
        std::unique_lock<std::mutex> lock(mutex);
        ready.wait(lock, [&]{return !queue.empty();});
        current = queue.front(); queue.pop_front(); setg(&current, &current, &current+1);
        return traits_type::to_int_type(current);
    }
};
class OutputBuffer : public std::streambuf {
    std::string line;
public:
    CVEngineCallback callback = nullptr;
    int_type overflow(int_type ch) override {
        if (traits_type::eq_int_type(ch, traits_type::eof())) return traits_type::not_eof(ch);
        char c = traits_type::to_char_type(ch);
        if (c == '\n') { if (callback) callback(line.c_str()); line.clear(); } else line += c;
        return ch;
    }
};
// Process lifetime: Stockfish's global state supports exactly one engine instance.
// All C++ iostream use in this app is reserved for Stockfish. Swift logs are unaffected.
InputBuffer input;
OutputBuffer output;
std::once_flag once;
}
extern "C" void cv_engine_start(CVEngineCallback callback) {
    std::call_once(once, [callback] {
        output.callback = callback;
        std::cin.rdbuf(&input); std::cout.rdbuf(&output);
        std::thread([] {
            UCI::init(Options); PSQT::init(); Bitboards::init(); Position::init();
            Bitbases::init(); Endgames::init(); Threads.set(1); Search::clear();
            char name[] = "ChessVision"; char *args[] = {name}; UCI::loop(1, args);
            Threads.set(0);
        }).detach();
    });
}
extern "C" void cv_engine_send(const char *command) { if (command) input.send(command); }
