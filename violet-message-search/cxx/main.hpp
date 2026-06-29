#include <string>

#include "rapidfuzz/fuzz.hpp"

#ifndef MAIN_H
#define MAIN_H

namespace binding {

struct CachedRatioBinding {
  rapidfuzz::fuzz::CachedRatio<typename std::string::value_type> inner;

public:
  CachedRatioBinding(const std::string &query) : inner(query) {}
};

extern "C" struct CachedRatioBinding *create(const char *query);

extern "C" double similarity(struct CachedRatioBinding *binding,
                             const char *message);

struct CachedPartialRatioBinding {
  rapidfuzz::fuzz::CachedPartialRatio<typename std::string::value_type> inner;

public:
  CachedPartialRatioBinding(const std::string &query) : inner(query) {}
};

extern "C" struct CachedPartialRatioBinding *create_partial(const char *query);

extern "C" double similarity_partial(struct CachedPartialRatioBinding *binding,
                                     const char *message);

} // namespace binding

#endif