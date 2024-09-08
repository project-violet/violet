// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api.swagger.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$Api extends Api {
  _$Api([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = Api;

  @override
  Future<Response<dynamic>> _apiV2Get() {
    final Uri $url = Uri.parse('/api/v2');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2HmacGet() {
    final Uri $url = Uri.parse('/api/v2/hmac');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2CommentGet({required CommentGetDto? body}) {
    final Uri $url = Uri.parse('/api/v2/comment');
    final $body = body;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2CommentPost({required CommentPostDto? body}) {
    final Uri $url = Uri.parse('/api/v2/comment');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2UserPost({required UserRegisterDTO? body}) {
    final Uri $url = Uri.parse('/api/v2/user');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2UserDiscordGet() {
    final Uri $url = Uri.parse('/api/v2/user/discord');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<User>> _apiV2AuthGet() {
    final Uri $url = Uri.parse('/api/v2/auth');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<User, User>($request);
  }

  @override
  Future<Response<Tokens>> _apiV2AuthPost({required UserRegisterDTO? body}) {
    final Uri $url = Uri.parse('/api/v2/auth');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<Tokens, Tokens>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2AuthDelete() {
    final Uri $url = Uri.parse('/api/v2/auth');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2AuthRefreshGet() {
    final Uri $url = Uri.parse('/api/v2/auth/refresh');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2AuthDiscordGet() {
    final Uri $url = Uri.parse('/api/v2/auth/discord');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2AuthDiscordRedirectGet() {
    final Uri $url = Uri.parse('/api/v2/auth/discord/redirect');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2ViewGet({
    required num? offset,
    required num? count,
    String? type,
  }) {
    final Uri $url = Uri.parse('/api/v2/view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'offset': offset,
      'count': count,
      'type': type,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2ViewPost({
    required num? articleId,
    required num? viewSeconds,
    required String? userAppId,
  }) {
    final Uri $url = Uri.parse('/api/v2/view');
    final Map<String, dynamic> $params = <String, dynamic>{
      'articleId': articleId,
      'viewSeconds': viewSeconds,
      'userAppId': userAppId,
    };
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> _apiV2ViewLoginedPost({
    required num? articleId,
    required num? viewSeconds,
    required String? userAppId,
  }) {
    final Uri $url = Uri.parse('/api/v2/view/logined');
    final Map<String, dynamic> $params = <String, dynamic>{
      'articleId': articleId,
      'viewSeconds': viewSeconds,
      'userAppId': userAppId,
    };
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
