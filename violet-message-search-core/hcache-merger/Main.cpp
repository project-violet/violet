//===----------------------------------------------------------------------===//
//
//                             HCache-Merger
//
//===----------------------------------------------------------------------===//
//
//  Copyright (C) 2021. violet-dev. All Rights Reserved.
//
//===----------------------------------------------------------------------===//

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

#include "json.hpp"

const std::string target_dir = "/home/ubuntu/htext-miner/cache";

int main(int argc, char *argv[]) {
  if (argc == 1) {
    std::cout << argv[0] << " <count of split file>";
    return 0;
  }

  int count_of_split_file = atoi(argv[1]);

  std::vector<nlohmann::json *> result;

  for (int i = 0; i < count_of_split_file; i++)
    result.push_back(new nlohmann::json());

  int count{};
  for (auto &p : std::filesystem::directory_iterator(target_dir))
    ++count;
  int count_process = 0;
  for (const auto &entry : std::filesystem::directory_iterator(target_dir)) {
    std::cout << ++count_process << '/' << count << entry.path() << std::endl;

    std::ifstream i(entry.path());
    nlohmann::json j;
    i >> j;

    for (const auto &item : j.items())
      result[(count_process - 1) % count_of_split_file]->push_back(item.value());
  }

  for (int i = 0; i < count_of_split_file; i++) {
    std::ofstream o(std::string("merged-") + std::to_string(i) + std::string(".json"));
    o << *result[i] << std::endl;
  }
}