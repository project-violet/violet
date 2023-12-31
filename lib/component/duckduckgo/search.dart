import 'package:http/http.dart' as http;
import 'package:violet/component/proxy/proxy.myvipwebtools.com.dart';

class DuckDuckGoSearch {
  Future<http.Response> search(String query) async {
    final res = await http.get(Uri.parse(
        'https://lite.duckduckgo.com/lite/?q=${Uri.encodeComponent(query)}'));
    return res;
  }

  Future<http.Response> searchProxied(String query) async {
    final target =
        'https://lite.duckduckgo.com/lite/?q=${Uri.encodeComponent(query)}';
    ProxyHttpRequest phr = ProxyHttpRequest();
    final res = await phr.get(target);
    return res;
  }
}
