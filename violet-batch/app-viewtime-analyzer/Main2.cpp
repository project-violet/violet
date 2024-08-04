//===----------------------------------------------------------------------===//
//
//                     Fast Search for Comic Message
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2022. violet-dev. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

#include <algorithm>
#include <chrono>
#include <cmath>
#include <ctime>
#include <fstream>
#include <functional>
#include <iostream>
#include <locale>
#include <map>
#include <mutex>
#include <regex>
#include <sstream>
#include <string>

#include "simdjson.h"

using namespace simdjson;

int main() {
  setlocale(LC_ALL, "");
  std::wcin.imbue(std::locale(""));
  std::wcout.imbue(std::locale(""));

  ondemand::parser parser;
  padded_string json = padded_string::load("r.txt");
  ondemand::document tweets = parser.iterate(json);

  std::map<int, std::vector<std::pair<int, double>>> article_connectom;

  for (auto x : tweets) {
    auto arr = x.get_array();
    int index = 0;

    int cid, pid;
    double conn;

    for (auto y : arr) {
      if (index == 0)
        cid = y.get_int64();
      else if (index == 1)
        pid = y.get_int64();
      else if (index == 2)
        conn = y.get_double();
      index += 1;
    }

    if (cid == pid)
      continue;

    if (article_connectom.find(cid) == article_connectom.end())
      article_connectom[cid] = std::vector<std::pair<int, double>>();
    article_connectom[cid].push_back({pid, conn});
  }

  std::ofstream fout;
  fout.open("rx.txt", std::ios::app);
  fout << '{';
  int j = 0;
  for (auto kv : article_connectom) {
    fout << "\"" << kv.first << "\":[";

    for (int i = 0; i < kv.second.size() && i < 30; i++) {
      fout << kv.second[i].first;
      if (i < kv.second.size() - 1 && i < 30 - 1)
        fout << ",";
    }

    fout << "]";
    if (j++ < article_connectom.size() - 1)
      fout << ",";
  }
  //   for (int i = 0; i < article_article_conn.size(); i++) {
  //     int x, y;
  //     double z;
  //     std::tie(x, y, z) = article_article_conn[i];
  //     fout << '[';
  //     fout << x << ',' << y << ',' << z;
  //     fout << ']';
  //     if (i != article_article_conn.size() - 1)
  //       fout << ",";
  //   }
  fout << '}';
}