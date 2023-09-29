//===----------------------------------------------------------------------===//
//
//                     Fast Search for Comic Message
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2021-2022. violet-dev. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

#include <algorithm>
#include <chrono>
#include <cmath>
#include <ctime>
#include <functional>
#include <iostream>
#include <locale>
#include <map>
#include <mutex>
#include <set>
#include <sstream>
#include <string>

#include "Displant.h"
#include "httplib.h"
#include "rapidfuzz/fuzz.hpp"
#include "rapidfuzz/utils.hpp"
#include "simdjson.h"

using namespace simdjson;

std::map<std::string, std::string> cacheSimilar;
std::map<std::string, int> cacheSimilarHit;
std::map<std::string, std::string> cacheContains;
std::map<std::string, int> cacheContainsHit;
std::map<std::string, std::string> cacheLCS;
std::map<std::string, int> cacheLCSHit;

std::mutex mutex_similar;
std::mutex mutex_contains;
std::mutex mutex_lcs;

typedef struct _MergedInfo {
  int articleid;
  double page;
  std::string message;
  double score;
  std::vector<double> rects;

  _MergedInfo(int articleid, double page, std::string message, double score,
              std::vector<double> rects)
      : articleid(articleid), page(page), message(message), score(score),
        rects(rects) {}

  static struct _MergedInfo *create(int articleid, double page,
                                    std::string message, double score,
                                    std::vector<double> rects) {
    return new _MergedInfo(articleid, page, message, score, rects);
  }
} MergedInfo;

//
//  Merged 문장이 들어있는 벡터
//
std::vector<MergedInfo *> m_infos;

std::vector<std::tuple<int, int, std::set<int>>> m_db;
std::map<std::string, int> m_tagmap;
std::map<std::string, int> m_typemap;

void load_json() {
  //
  //  merged.json 파일 로드
  //
  ondemand::parser parser;
  padded_string json = padded_string::load("merged.json");
  ondemand::document tweets = parser.iterate(json);

  for (auto x : tweets) {
    auto id = x["ArticleId"].get_int64();
    auto page = x["Page"].get_double();
    auto msg = std::string_view(x["Message"]);
    auto score = x["Score"].get_double();
    std::vector<double> rects;
    rects.push_back(x["Rectangle"].at(0).get_double());
    rects.push_back(x["Rectangle"].at(1).get_double());
    rects.push_back(x["Rectangle"].at(2).get_double());
    rects.push_back(x["Rectangle"].at(3).get_double());

    m_infos.push_back(MergedInfo::create(
        (int)id.value(), page.value(), std::string(msg), score.value(), rects));
  }
}

// https://stackoverflow.com/questions/997946/how-to-get-current-time-and-date-in-c
const std::string currentDateTime() {
  time_t now = time(0);
  struct tm tstruct;
  char buf[80];
  tstruct = *localtime(&now);
  // Visit http://en.cppreference.com/w/cpp/chrono/c/strftime
  // for more information about date/time format
  strftime(buf, sizeof(buf), "%Y-%m-%d.%X", &tstruct);

  return buf;
}

#if _WIN32
std::wstring s2ws(const std::string &str) {
  int size_needed =
      MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0],
                      size_needed);
  return wstrTo;
}

std::string kor2Eng(const char *target) {
  auto search = s2ws(std::string(target));
  char kor2engtypo[1024 * 3];
  Utility::HangulConverter::total_disassembly(search.c_str(), kor2engtypo);
  return std::string(kor2engtypo);
}

#else
std::string kor2Eng(const char* target) {
    //
    //  HangulConverter가 wchar_t 기반으로 구현되어 있어서
    //  utf-8 => unicode 해줘야함
    //
    wchar_t unicode[1024];
    std::mbstowcs(unicode, target, 1024);
    char kor2engtypo[1024 * 3];
    Utility::HangulConverter::total_disassembly(unicode, kor2engtypo);
    return std::string(kor2engtypo);
}
#endif

std::string
result2Json(const std::vector<std::pair<MergedInfo *, double>> &result,
            int count) {
  std::stringstream ss;
  int m = 0;
  ss << "[";
  for (auto i : result) {
    ss << "{";
    ss << "\"MatchScore\":\"" << i.second << "\",";
    ss << "\"Id\":" << i.first->articleid << ",";
    ss << "\"Page\":" << (int)i.first->page << ",";
    ss << "\"Correctness\":" << i.first->score << ",";
    ss << "\"Rect\":[" << i.first->rects[0] << "," << i.first->rects[1] << ","
       << i.first->rects[2] << "," << i.first->rects[3] << "]";
    ss << "}";
    if (m == count || result.size() - 1 == m)
      break;
    m++;
    ss << ",";
  }
  ss << "]";

  return std::string(std::istreambuf_iterator<char>(ss), {});
}

template <class Func>
void route_internal(const httplib::Request &req, httplib::Response &res,
                    bool use_cache, int count, const char *type,
                    std::map<std::string, std::string> &cache,
                    std::map<std::string, int> cache_hit, std::mutex &lock,
                    Func &extractor) {
  auto query = req.matches[1];

  if (strlen(&*query.first) == 0) {
    res.set_content("", "text/json");
    return;
  }

  std::cout << "(" << currentDateTime() << ") " << type << ": " << &*query.first
            << " | " << std::endl;

  auto search = std::string(&*query.first);
  auto target = kor2Eng(&*query.first);

  if (use_cache && cache.find(target) != cache.end()) {
    lock.lock();
    cache_hit.find(search)->second = cache_hit.find(search)->second + 1;
    lock.unlock();
    res.set_content(cache.find(target)->second, "text/json");
    return;
  }

  std::vector<std::pair<MergedInfo *, double>> r = extractor(target, m_infos);

  std::sort(r.begin(), r.end(), [](auto first, auto second) -> bool {
    return first.second > second.second;
  });

  //
  //  결과 출력
  //
  std::string json = result2Json(r, count);

  lock.lock();
  if (use_cache && cache.find(target) == cache.end()) {
    cache.insert({target, json});
    cache_hit.insert({search, 0});
  }
  lock.unlock();

  res.set_content(json, "text/json");
}

template <class Func>
void route_winternal(const httplib::Request &req, httplib::Response &res,
                     bool use_cache, int count, const char *type,
                     std::map<std::string, std::string> &cache,
                     std::map<std::string, int> cache_hit, std::mutex &lock,
                     Func &extractor) {
  auto query1 = req.matches[1];
  auto query2 = req.matches[2];

  if (strlen(&*query1.first) == 0 || strlen(&*query2.first) == 0) {
    res.set_content("", "text/json");
    return;
  }

  std::cout << "(" << currentDateTime() << ") " << type << ": "
            << &*query2.first << " | " << &*query1.first << std::endl;

  auto search = std::string(&*query2.first);
  auto target = kor2Eng(&*query2.first);

  std::vector<MergedInfo *> search_target;
  int target_id = atoi(&*query1.first);
  for (auto &minfo : m_infos) {
    if (minfo->articleid == target_id)
      search_target.push_back(minfo);
  }

  std::vector<std::pair<MergedInfo *, double>> r =
      extractor(target, search_target);

  std::sort(r.begin(), r.end(), [](auto first, auto second) -> bool {
    return first.second > second.second;
  });

  //
  //  결과 출력
  //
  std::string json = result2Json(r, count);

  res.set_content(json, "text/json");
}

std::vector<std::pair<MergedInfo *, rapidfuzz::percent>>
extract_similar(const std::string &query,
                const std::vector<MergedInfo *> &choices) {
  std::vector<std::pair<MergedInfo *, rapidfuzz::percent>> results(
      choices.size());

  auto scorer = rapidfuzz::fuzz::CachedRatio<std::string>(query);

#pragma omp parallel for
  for (int i = 0; i < choices.size(); ++i) {
    double score = scorer.ratio(choices[i]->message, 0.0);
    results[i] = std::make_pair(choices[i], score);
  }

  return results;
}

std::vector<std::pair<MergedInfo *, rapidfuzz::percent>>
extract_partial_contains(const std::string &query,
                         const std::vector<MergedInfo *> &choices) {
  std::vector<std::pair<MergedInfo *, rapidfuzz::percent>> results(
      choices.size());
  auto query_len = query.length();

  auto scorer = rapidfuzz::fuzz::CachedPartialRatio<std::string>(query);

#pragma omp parallel for
  for (int i = 0; i < choices.size(); ++i) {
    if (choices[i]->message.length() < query_len) {
      results[i] = std::make_pair(choices[i], 0.0);
      continue;
    }
    double score = scorer.ratio(choices[i]->message, 0.0);
    results[i] = std::make_pair(choices[i], score);
  }

  return results;
}

std::vector<std::pair<MergedInfo *, rapidfuzz::percent>>
extract_lcs(const std::string &query,
            const std::vector<MergedInfo *> &choices) {
  std::vector<std::pair<MergedInfo *, rapidfuzz::percent>> results(
      choices.size());
  auto query_len = query.length();

  auto scorer = rapidfuzz::fuzz::CachedRatio<std::string>(query);

#pragma omp parallel for
  for (int i = 0; i < choices.size(); ++i) {
    auto s_len = choices[i]->message.length();
    if (s_len < query_len) {
      results[i] = std::make_pair(choices[i], 0.0);
      continue;
    }

    double score = scorer.ratio(choices[i]->message, 0.0);

    // s2길이 > s1길이 일때
    // score값 - (s2길이 - s1길이)이 실질적인 score값임
    // s2의 길이가 s1보다 1만큼 길면 score값이 무조건 1만큼 커지게됨
    // 이걸 보정해주는게 (s2길이 - s2길이)임
    double ed = (100 - score) / 100 * (query_len + s_len);
    double lcs = (query_len + s_len - ed) / 2;

    results[i] = std::make_pair(choices[i], lcs / query_len);
  }

  return results;
}

template <typename Sentence1, typename Iterable,
          typename Sentence2 = typename Iterable::value_type>
std::vector<std::pair<Sentence2, rapidfuzz::percent>>
extract_regional_partial_contains(const Sentence1 &query,
                                  const Iterable &choices,
                                  const rapidfuzz::percent score_cutoff = 0.0) {
  std::vector<std::pair<Sentence2, rapidfuzz::percent>> results(choices.size());
  auto query_len = query.length();

  auto scorer1 = rapidfuzz::fuzz::CachedRatio<Sentence1>(query);
  auto scorer2 = rapidfuzz::fuzz::CachedPartialRatio<Sentence1>(query);

#pragma omp parallel for
  for (int i = 0; i < choices.size(); ++i) {
    if (choices[i]->message.length() < query_len) {
      results[i] = std::make_pair(choices[i], 0.0);
      continue;
    }
    double score1 = scorer1.ratio(choices[i]->message, score_cutoff);
    double score2 = scorer2.ratio(choices[i]->message, score_cutoff);

    double score1_rev = (1 - score1 / 100) * (choices[i]->message + query_len);

    results[i] = std::make_pair(choices[i], score2);
  }

  return results;
}

inline void route_similar(const httplib::Request &req, httplib::Response &res,
                          bool use_cache = true, int count = 15) {
  route_internal(req, res, use_cache, count, "similar", cacheSimilar,
                 cacheSimilarHit, mutex_similar, extract_similar);
}

inline void route_contains(const httplib::Request &req, httplib::Response &res,
                           bool use_cache = true, int count = 50) {
  route_internal(req, res, use_cache, count, "contains", cacheContains,
                 cacheContainsHit, mutex_contains, extract_partial_contains);
}

inline void route_wcontains(const httplib::Request &req, httplib::Response &res,
                            bool use_cache = true, int count = 50) {
  route_winternal(req, res, use_cache, count, "wcontains", cacheContains,
                  cacheContainsHit, mutex_contains, extract_partial_contains);
}

inline void route_lcs(const httplib::Request &req, httplib::Response &res,
                      bool use_cache = true, int count = 50) {
  route_internal(req, res, use_cache, count, "lcs", cacheLCS, cacheLCSHit,
                 mutex_lcs, extract_lcs);
}

int main(int argc, char **argv) {
  setlocale(LC_ALL, "");
  std::wcout.imbue(std::locale(""));

  if (argc < 4) {
    std::cout << "fast-search binary\n";
    std::cout << "use " << argv[0] << " <host> <port> <private-access-token>";
    return 0;
  }

  load_json();

  //
  //  Private Access Token 정의
  //
  std::string token = std::string(argv[3]);

  //
  //  Http 서버 정의
  //
  httplib::Server svr;

  //
  //  /similar/ 라우팅
  //
  svr.Get(R"(/similar/(.*?))", std::bind(route_similar, std::placeholders::_1,
                                         std::placeholders::_2, true, 1000));

  //
  //  /contains/ 라우팅
  //
  svr.Get(R"(/contains/(.*?))", std::bind(route_contains, std::placeholders::_1,
                                          std::placeholders::_2, true, 1000));

  //
  //  /wcontains/ 라우팅
  //
  svr.Get(R"(/wcontains/(.*?)/(.*?))",
          std::bind(route_wcontains, std::placeholders::_1,
                    std::placeholders::_2, true, 1000));

  //
  //  /containsh/ 라우팅
  //
  svr.Get(R"(/lcs/(.*?))", std::bind(route_lcs, std::placeholders::_1,
                                     std::placeholders::_2, true, 1000));

  //
  //  /<private-access-token>/*/ 라우팅
  //
  svr.Get("/" + token + R"(/similar/(.*?))",
          std::bind(route_similar, std::placeholders::_1, std::placeholders::_2,
                    false, 500));
  svr.Get("/" + token + R"(/contains/(.*?))",
          std::bind(route_contains, std::placeholders::_1,
                    std::placeholders::_2, false, 500));
  svr.Get("/" + token + R"(/lcs/(.*?))",
          std::bind(route_lcs, std::placeholders::_1, std::placeholders::_2,
                    false, 500));

  //
  //  /rank 라우팅
  //
  svr.Get(R"(/rank)", [](const httplib::Request &req, httplib::Response &res) {
    std::stringstream result;

    for (auto ss : cacheSimilarHit) {
      result << "(similar) " << ss.first << ": " << ss.second << "\n";
    }

    for (auto ss : cacheContainsHit) {
      result << "(contains) " << ss.first << ": " << ss.second << "\n";
    }

    for (auto ss : cacheLCS) {
      result << "(lcs) " << ss.first << ": " << ss.second << "\n";
    }

    std::string json(std::istreambuf_iterator<char>(result), {});

    res.set_content(json, "text/json");
  });

  std::cout << "start server." << std::endl;

  svr.listen(argv[1], std::atoi(argv[2]));
}
