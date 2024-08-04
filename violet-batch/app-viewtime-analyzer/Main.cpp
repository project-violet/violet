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

typedef struct _DATA_ {
  std::string id;
  std::string date;
  std::string userid;

  _DATA_(std::string id, std::string date, std::string userid)
      : id(id), date(date), userid(userid) {}

  static struct _DATA_ *create(std::string id, std::string date,
                               std::string userid) {
    return new _DATA_(id, date, userid);
  }
} data;

int main() {
  setlocale(LC_ALL, "");
  std::wcin.imbue(std::locale(""));
  std::wcout.imbue(std::locale(""));

  std::vector<data *> m_infos;

  std::map<std::string, std::vector<int>> user_read_map;

  for (int i = 0; i < 23; i++) {
    std::cout << "load... " << i << std::endl;

    ondemand::parser parser;
    padded_string json = padded_string::load("cache/viewtime-cache-" +
                                             std::to_string(i) + ".json");
    ondemand::document tweets = parser.iterate(json);

    for (auto x : tweets) {
      auto str = std::string(std::string_view(x));

      std::replace(str.begin(), str.end(), '(', ' ');
      std::replace(str.begin(), str.end(), ')', ' ');
      std::replace(str.begin(), str.end(), ',', ' ');

      std::stringstream ss(str);
      std::string id, date, userid;

      ss >> id >> date >> userid;

      m_infos.push_back(data::create(id, date, userid));
    }
  }

  for (auto i : m_infos) {
    if (user_read_map.find(i->userid) == user_read_map.end()) {
      user_read_map[i->userid] = std::vector<int>();
    }

    user_read_map[i->userid].push_back(std::atoi(i->id.c_str()));
  }

  const double weight[] = {
      0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.1, 1.3, 1.5, -1,
      1.5, 1.3, 1.1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3,
  };

  std::map<int, std::map<int, double>> article_connectom;

  for (auto kv : user_read_map) {
    for (int i = 1; i < kv.second.size(); i++) {
      auto cid = kv.second[i];

      if (article_connectom.find(cid) == article_connectom.end())
        article_connectom[cid] = std::map<int, double>();

      for (int j = -10; j <= 10; j++) {
        if (i + j < 0 || i + j >= kv.second.size() || j == 0)
          continue;

        auto pid = kv.second[i + j];

        if (article_connectom[cid].find(pid) == article_connectom[cid].end())
          article_connectom[cid][pid] = 0;

        article_connectom[cid][pid] += weight[j + 10];
      }
    }
  }

  std::vector<std::tuple<int, int, double>> article_article_conn;

  for (auto kv1 : article_connectom) {
    for (auto kv2 : kv1.second) {
      if (kv2.second < 2.0)
        continue;
      if (kv1.first == kv2.first)
        continue;
      article_article_conn.push_back({kv1.first, kv2.first, kv2.second});
    }
  }

  std::sort(article_article_conn.begin(), article_article_conn.end(),
            [](const std::tuple<int, int, double> &a,
               const std::tuple<int, int, double> &b) -> bool {
              return std::get<2>(a) > std::get<2>(b);
            });

  std::ofstream fout;
  fout.open("r.txt", std::ios::app);
  fout << '[';
  for (int i = 0; i < article_article_conn.size(); i++) {
    int x, y;
    double z;
    std::tie(x, y, z) = article_article_conn[i];
    fout << '[';
    fout << x << ',' << y << ',' << z;
    fout << ']';

    if (i != article_article_conn.size() - 1)
      fout << ",";
  }
  fout << ']';
}