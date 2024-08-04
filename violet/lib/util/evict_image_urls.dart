import 'package:cached_network_image/cached_network_image.dart';

Future<void> evictImageUrls(Iterable<String>? urls) async {
  if (urls == null) {
    return;
  }

  for (final url in urls) {
    await CachedNetworkImageProvider(url).evict();
  }
}
