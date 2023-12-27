import 'package:http/http.dart' as _http;
import 'package:violet/component/duckduckgo/proxy.dart';
import 'package:violet/network/wrapper.dart' as http;
class DuckDuckGoSearch {
  Future<_http.Response> search(String query) async {
    final res = await http.get('https://lite.duckduckgo.com/lite/?q=${Uri.encodeComponent(query)}');
    return res;
  }
  Future<_http.Response> searchProxied(String query) async {
    final target = 'https://lite.duckduckgo.com/lite/?q=${Uri.encodeComponent(query)}';
    ProxyHttpRequest phr =  ProxyHttpRequest();
    final res = await phr.get(target,host: phr.hosts[0]);
    return res;
  }
}