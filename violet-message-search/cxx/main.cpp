
#include "main.hpp"
#include "rapidfuzz/fuzz.hpp"

using namespace binding;

extern "C" struct CachedRatioBinding *create(const char *query) {
  return new CachedRatioBinding(std::string(query));
}

extern "C" double similarity(struct CachedRatioBinding *binding,
                             const char *message, size_t message_len,
                             double score_cutoff) {
  return binding->inner.similarity(message, message + message_len, score_cutoff);
}

extern "C" struct CachedPartialRatioBinding *create_partial(const char *query) {
  return new CachedPartialRatioBinding(std::string(query));
}

extern "C" double similarity_partial(struct CachedPartialRatioBinding *binding,
                                     const char *message, size_t message_len,
                                     double score_cutoff) {
  return binding->inner.similarity(message, message + message_len, score_cutoff);
}
