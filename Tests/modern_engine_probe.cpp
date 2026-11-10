#include "StockfishBridge.h"
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <string>
#include <chrono>
#include <cstdlib>
namespace {
std::mutex guard;
std::condition_variable changed;
bool ready=false, finished=false;
std::string last, best, failure;
void receive(const char* line) {
    std::lock_guard<std::mutex> lock(guard);
    std::string text(line);
    if (text=="readyok") ready=true;
    if (text.rfind("info depth ",0)==0 && text.find(" pv ")!=std::string::npos && text.find("bound")==std::string::npos) last=text;
    if (text.rfind("bestmove ",0)==0) { best=text; finished=true; }
    if (text.rfind("engineerror ",0)==0) { failure=text; finished=true; }
    changed.notify_all();
}
}
int main(int argc,char** argv) {
    if(argc!=4)return 2;
    cv_modern_start(receive,argv[1]);
    for (const auto& command : {"uci", "setoption name Threads value 1", "setoption name Hash value 16", "setoption name MultiPV value 1", "setoption name UCI_LimitStrength value false", "setoption name Skill Level value 20", "ucinewgame", "isready"}) cv_modern_send(command);
    {
        std::unique_lock<std::mutex> lock(guard);
        if(!changed.wait_for(lock,std::chrono::seconds(30),[]{return ready||!failure.empty();}))return 3;
        if(!failure.empty()){std::fprintf(stderr,"%s\n",failure.c_str());std::_Exit(4);}
    }
    cv_modern_send((std::string("position fen ")+argv[2]).c_str());
    cv_modern_send((std::string("go depth ")+argv[3]).c_str());
    {
        std::unique_lock<std::mutex> lock(guard);
        if(!changed.wait_for(lock,std::chrono::seconds(60),[]{return finished;}))return 5;
        std::printf("RESULT\t%s\n%s\n",last.c_str(),best.c_str());std::fflush(stdout);
        if(!failure.empty()){std::fprintf(stderr,"%s\n",failure.c_str());std::_Exit(4);}
    }
    std::_Exit(0);
}
