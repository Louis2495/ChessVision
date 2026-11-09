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
#include "psqt.h"
#include "piece.h"
#include "variant.h"
#include "evaluate.h"
#include "tune.h"
#include "apiutil.h"
#include <atomic>
#include <cctype>
#include <vector>
#include <sstream>
#include <cstdlib>
#include <cstring>
using namespace Stockfish;
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
std::atomic<bool> initialized{false};
}
extern "C" void cv_engine_start(CVEngineCallback callback) {
    std::call_once(once, [callback] {
        output.callback = callback;
        std::cin.rdbuf(&input); std::cout.rdbuf(&output);
        std::thread([] {
            char name[] = "ChessVision"; char *args[] = {name};
            pieceMap.init(); variants.init();
            // App variants use the same rules/search engine as the built-in games.
            std::istringstream custom(R"ini(
[cvfog:chess]
king = -
commoner = k
castlingKingPiece = k
extinctionValue = loss
extinctionPieceTypes = k
stalemateValue = draw
[cvpawns:chess]
startFen = 4k3/pppppppp/8/8/8/8/PPPPPPPP/4K3 w - - 0 1
castling = false
[cvpawnrace:chess]
king = -
startFen = 8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1
castling = false
promotionPieceTypes = -
mandatoryPawnPromotion = false
flagPiece = p
flagRegionWhite = *8
flagRegionBlack = *1
extinctionValue = loss
extinctionPieceTypes = *
stalemateValue = loss
)ini");
            variants.parse_istream<false>(custom);
            // Scharnagl numbering enumerates all 960 legal back ranks.
            std::ostringstream starts;
            for (int index = 0; index < 960; ++index) {
                int n = index; std::string rank(8, ' ');
                rank[(n % 4) * 2 + 1] = 'B'; n /= 4;
                rank[(n % 4) * 2] = 'B'; n /= 4;
                auto emptyFiles = [&] { std::vector<int> files; for (int f = 0; f < 8; ++f) if (rank[f] == ' ') files.push_back(f); return files; };
                auto files = emptyFiles(); rank[files[n % 6]] = 'Q'; n /= 6;
                files = emptyFiles(); int pair = 0;
                for (int a = 0; a < 4; ++a) for (int b = a + 1; b < 5; ++b) if (pair++ == n) { rank[files[a]] = 'N'; rank[files[b]] = 'N'; }
                files = emptyFiles(); rank[files[0]] = 'R'; rank[files[1]] = 'K'; rank[files[2]] = 'R';
                std::string black = rank; for (char &ch : black) ch = char(std::tolower(ch));
                starts << "[cv960" << index << ":chess]\nstartFen = " << black << "/pppppppp/8/8/8/8/PPPPPPPP/" << rank << " w KQkq - 0 1\n";
            }
            std::istringstream randomized(starts.str()); variants.parse_istream<false>(randomized);
            CommandLine::init(1, args);
            UCI::init(Options); Tune::init(); Options["Use NNUE"] = std::string("false");
            PSQT::init(variants.find("chess")->second); Bitboards::init(); Position::init();
            Bitbases::init(); Endgames::init(); Threads.set(1); Search::clear(); Eval::NNUE::init();
            initialized = true;
            UCI::loop(1, args);
            Threads.set(0);
        }).detach();
    });
}
extern "C" void cv_engine_send(const char *command) { if (command) input.send(command); }

extern "C" char* cv_rules_query(const char *variantName, const char *history) {
    // Call only after the UCI ready barrier for this variant. During a game, its tables stay read-only.
    std::string result;
    const std::string name = variantName ? variantName : "";
    if (!initialized || (name != "chess" && name != "3check" && name != "kingofthehill" && name != "horde" && name != "crazyhouse" && name != "duck" && name != "atomic" && name != "antichess" && name != "cvfog" && name != "cvpawns" && name != "cvpawnrace" && !(name.rfind("cv960", 0) == 0 && variants.find(name) != variants.end()))) result = "error\tUnsupported or uninitialized variant";
    else if (std::string(Options["UCI_Variant"]) != name) result = "error\tThe engine has not prepared this variant";
    else {
        const Variant* variant = variants.find(name)->second;
        std::deque<StateInfo> states(1);
        Position position;
        position.set(variant, variant->startFen, name.rfind("cv960", 0) == 0, &states.back(), Threads.main());
        std::istringstream moves(history ? history : "");
        std::string token;
        bool valid = true;
        while (moves >> token) {
            if (token.size() > 16) { valid = false; break; }
            Move move = UCI::to_move(position, token);
            if (move == MOVE_NONE) { valid = false; break; }
            states.emplace_back(); position.do_move(move, states.back());
        }
        if (!valid) result = "error\tAn illegal move was found in the saved game";
        else {
            std::ostringstream data;
            data << "fen\t" << position.fen(false, true) << "\n";
            data << "turn\t" << (position.side_to_move() == WHITE ? "w" : "b") << "\n";
            data << "check\t" << (position.checkers() ? "1" : "0") << "\n";
            Value value = VALUE_ZERO;
            const bool specialEnd = position.is_game_end(value);
            const auto legal = MoveList<LEGAL>(position);
            std::string status = "ongoing";
            if (specialEnd || legal.size() == 0) {
                if (!specialEnd) value = position.checkers() ? position.checkmate_value() : position.stalemate_value();
                if (value == VALUE_DRAW) status = "draw";
                else { const Color winner = value > 0 ? position.side_to_move() : ~position.side_to_move(); status = winner == WHITE ? "white" : "black"; }
            }
            data << "status\t" << status << "\n";
            if (name == "cvfog") {
                data << "hidden\t";
                Bitboard fog = position.fog_area();
                bool first = true;
                while (fog) { const Square square = pop_lsb(fog); if (!first) data << ','; first = false; data << UCI::square(position, square); }
                data << "\n";
            }
            if (status == "ongoing") for (const auto &entry : legal) {
                const Move move = entry;
                const std::string uci = UCI::move(position, move);
                std::string san = SAN::move_to_san(position, move, NOTATION_SAN);
                if (san.rfind("P@", 0) == 0) san.erase(0, 1);
                StateInfo after;
                position.do_move(move, after);
                Value outcome = VALUE_ZERO;
                if (position.is_immediate_game_end(outcome) && outcome < VALUE_ZERO) {
                    while (!san.empty() && (san.back() == '+' || san.back() == '#')) san.pop_back();
                    san += '#';
                }
                position.undo_move(move);
                data << "move\t" << uci << "\t" << san << "\n";
            }
            result = data.str();
        }
    }
    char *copy = static_cast<char*>(std::malloc(result.size() + 1));
    if (copy) std::memcpy(copy, result.c_str(), result.size() + 1);
    return copy;
}
extern "C" void cv_rules_free(char *text) { std::free(text); }
