#include "StockfishBridge.h"
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
std::mutex mutex;
std::condition_variable ready;
int barriers=0;
bool uci=false;
void receive(const char* line) { std::lock_guard<std::mutex> lock(mutex); if(std::strcmp(line,"readyok")==0) ++barriers; if(std::strcmp(line,"uciok")==0) uci=true; ready.notify_all(); }
bool waitFor(int target) { std::unique_lock<std::mutex> lock(mutex);return ready.wait_for(lock,std::chrono::seconds(20),[&]{return target<0 ? uci : barriers>=target;}); }
int main() {
 cv_engine_start(receive);cv_engine_send("uci");if(!waitFor(-1))return 1;
 cv_engine_send("setoption name Use NNUE value false");
 std::string active;
 char* line=nullptr;size_t capacity=0;
 while(getline(&line,&capacity,stdin)>0) {
  std::string text(line);while(!text.empty()&&(text.back()=='\n'||text.back()=='\r'))text.pop_back();
  const auto tab=text.find('\t');if(tab==std::string::npos)return 2;
  const auto variant=text.substr(0,tab);const auto history=text.substr(tab+1);
  if(active!=variant) {
   cv_engine_send(("setoption name UCI_Variant value "+variant).c_str());
   int target;{std::lock_guard<std::mutex> lock(mutex);target=barriers+1;}
   cv_engine_send("isready");if(!waitFor(target))return 3;active=variant;
  }
  char* response=cv_rules_query(variant.c_str(),history.c_str());if(!response)return 4;
  std::printf("%s\nEND\n",response);std::fflush(stdout);cv_rules_free(response);
 }
 std::free(line);std::_Exit(0);
}
