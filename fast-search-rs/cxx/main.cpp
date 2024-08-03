
#include "main.hpp"
#include "rapidfuzz/fuzz.hpp"

using namespace binding;

extern "C" struct CachedRatioBinding *create(const char *query) {
  return new CachedRatioBinding(std::string(query));
}

extern "C" double similarity(struct CachedRatioBinding *binding,
                             const char *message) {
  return binding->inner.similarity(message, 0.0);
}
