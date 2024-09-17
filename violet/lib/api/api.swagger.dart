// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';
import 'package:collection/collection.dart';
import 'dart:convert';

import 'package:chopper/chopper.dart';

import 'client_mapping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartFile;
import 'package:chopper/chopper.dart' as chopper;

part 'api.swagger.chopper.dart';
part 'api.swagger.g.dart';

// **************************************************************************
// SwaggerChopperGenerator
// **************************************************************************

@ChopperApi()
abstract class Api extends ChopperService {
  static Api create({
    ChopperClient? client,
    http.Client? httpClient,
    Authenticator? authenticator,
    ErrorConverter? errorConverter,
    Converter? converter,
    Uri? baseUrl,
    Iterable<dynamic>? interceptors,
  }) {
    if (client != null) {
      return _$Api(client);
    }

    final newClient = ChopperClient(
        services: [_$Api()],
        converter: converter ?? $JsonSerializableConverter(),
        interceptors: interceptors ?? [],
        client: httpClient,
        authenticator: authenticator,
        errorConverter: errorConverter,
        baseUrl: baseUrl ?? Uri.parse('http://'));
    return _$Api(newClient);
  }

  ///
  Future<chopper.Response> apiV2Get() {
    return _apiV2Get();
  }

  ///
  @Get(path: '/api/v2')
  Future<chopper.Response> _apiV2Get();

  ///
  Future<chopper.Response> apiV2HmacGet() {
    return _apiV2HmacGet();
  }

  ///
  @Get(path: '/api/v2/hmac')
  Future<chopper.Response> _apiV2HmacGet();

  ///Get Comment
  Future<chopper.Response<CommentGetResponseDto>> apiV2CommentGet(
      {required CommentGetDto? body}) {
    generatedMapping.putIfAbsent(
        CommentGetResponseDto, () => CommentGetResponseDto.fromJsonFactory);

    return _apiV2CommentGet(body: body);
  }

  ///Get Comment
  @Get(path: '/api/v2/comment')
  Future<chopper.Response<CommentGetResponseDto>> _apiV2CommentGet(
      {@Body() required CommentGetDto? body});

  ///Post Comment
  Future<chopper.Response> apiV2CommentPost({required CommentPostDto? body}) {
    return _apiV2CommentPost(body: body);
  }

  ///Post Comment
  @Post(
    path: '/api/v2/comment',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2CommentPost(
      {@Body() required CommentPostDto? body});

  ///Register User
  Future<chopper.Response> apiV2UserPost({required UserRegisterDTO? body}) {
    return _apiV2UserPost(body: body);
  }

  ///Register User
  @Post(
    path: '/api/v2/user',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2UserPost(
      {@Body() required UserRegisterDTO? body});

  ///Get userAppIds registered by discord id
  Future<chopper.Response<ListDiscordUserAppIdsResponseDto>>
      apiV2UserDiscordGet() {
    generatedMapping.putIfAbsent(ListDiscordUserAppIdsResponseDto,
        () => ListDiscordUserAppIdsResponseDto.fromJsonFactory);

    return _apiV2UserDiscordGet();
  }

  ///Get userAppIds registered by discord id
  @Get(path: '/api/v2/user/discord')
  Future<chopper.Response<ListDiscordUserAppIdsResponseDto>>
      _apiV2UserDiscordGet();

  ///Get current user information
  Future<chopper.Response<User>> apiV2AuthGet() {
    generatedMapping.putIfAbsent(User, () => User.fromJsonFactory);

    return _apiV2AuthGet();
  }

  ///Get current user information
  @Get(path: '/api/v2/auth')
  Future<chopper.Response<User>> _apiV2AuthGet();

  ///Login
  Future<chopper.Response<Tokens>> apiV2AuthPost(
      {required UserRegisterDTO? body}) {
    generatedMapping.putIfAbsent(Tokens, () => Tokens.fromJsonFactory);

    return _apiV2AuthPost(body: body);
  }

  ///Login
  @Post(
    path: '/api/v2/auth',
    optionalBody: true,
  )
  Future<chopper.Response<Tokens>> _apiV2AuthPost(
      {@Body() required UserRegisterDTO? body});

  ///Logout
  Future<chopper.Response> apiV2AuthDelete() {
    return _apiV2AuthDelete();
  }

  ///Logout
  @Delete(path: '/api/v2/auth')
  Future<chopper.Response> _apiV2AuthDelete();

  ///Get refresh token
  Future<chopper.Response<ResLoginUser>> apiV2AuthRefreshGet() {
    generatedMapping.putIfAbsent(
        ResLoginUser, () => ResLoginUser.fromJsonFactory);

    return _apiV2AuthRefreshGet();
  }

  ///Get refresh token
  @Get(path: '/api/v2/auth/refresh')
  Future<chopper.Response<ResLoginUser>> _apiV2AuthRefreshGet();

  ///Login From Discord
  Future<chopper.Response> apiV2AuthDiscordGet() {
    return _apiV2AuthDiscordGet();
  }

  ///Login From Discord
  @Get(path: '/api/v2/auth/discord')
  Future<chopper.Response> _apiV2AuthDiscordGet();

  ///Redirect discord oauth2
  Future<chopper.Response> apiV2AuthDiscordRedirectGet() {
    return _apiV2AuthDiscordRedirectGet();
  }

  ///Redirect discord oauth2
  @Get(path: '/api/v2/auth/discord/redirect')
  Future<chopper.Response> _apiV2AuthDiscordRedirectGet();

  ///Get article read view
  ///@param offset Offset
  ///@param count Count
  ///@param type Type
  Future<chopper.Response<ViewGetResponseDto>> apiV2ViewGet({
    required num? offset,
    required num? count,
    String? type,
  }) {
    generatedMapping.putIfAbsent(
        ViewGetResponseDto, () => ViewGetResponseDto.fromJsonFactory);

    return _apiV2ViewGet(offset: offset, count: count, type: type);
  }

  ///Get article read view
  ///@param offset Offset
  ///@param count Count
  ///@param type Type
  @Get(path: '/api/v2/view')
  Future<chopper.Response<ViewGetResponseDto>> _apiV2ViewGet({
    @Query('offset') required num? offset,
    @Query('count') required num? count,
    @Query('type') String? type,
  });

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  Future<chopper.Response> apiV2ViewPost({
    required num? articleId,
    required num? viewSeconds,
    required String? userAppId,
  }) {
    return _apiV2ViewPost(
        articleId: articleId, viewSeconds: viewSeconds, userAppId: userAppId);
  }

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  @Post(
    path: '/api/v2/view',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2ViewPost({
    @Query('articleId') required num? articleId,
    @Query('viewSeconds') required num? viewSeconds,
    @Query('userAppId') required String? userAppId,
  });

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  Future<chopper.Response> apiV2ViewLoginedPost({
    required num? articleId,
    required num? viewSeconds,
    required String? userAppId,
  }) {
    return _apiV2ViewLoginedPost(
        articleId: articleId, viewSeconds: viewSeconds, userAppId: userAppId);
  }

  ///Post article read data
  ///@param articleId ArticleId
  ///@param viewSeconds Count
  ///@param userAppId User App Id
  @Post(
    path: '/api/v2/view/logined',
    optionalBody: true,
  )
  Future<chopper.Response> _apiV2ViewLoginedPost({
    @Query('articleId') required num? articleId,
    @Query('viewSeconds') required num? viewSeconds,
    @Query('userAppId') required String? userAppId,
  });
}

@JsonSerializable(explicitToJson: true)
class CommentGetDto {
  const CommentGetDto({
    required this.where,
  });

  factory CommentGetDto.fromJson(Map<String, dynamic> json) =>
      _$CommentGetDtoFromJson(json);

  static const toJsonFactory = _$CommentGetDtoToJson;
  Map<String, dynamic> toJson() => _$CommentGetDtoToJson(this);

  @JsonKey(name: 'where')
  final String where;
  static const fromJsonFactory = _$CommentGetDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentGetDto &&
            (identical(other.where, where) ||
                const DeepCollectionEquality().equals(other.where, where)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(where) ^ runtimeType.hashCode;
}

extension $CommentGetDtoExtension on CommentGetDto {
  CommentGetDto copyWith({String? where}) {
    return CommentGetDto(where: where ?? this.where);
  }

  CommentGetDto copyWithWrapped({Wrapped<String>? where}) {
    return CommentGetDto(where: (where != null ? where.value : this.where));
  }
}

@JsonSerializable(explicitToJson: true)
class CommentGetResponseDto {
  const CommentGetResponseDto({
    required this.elements,
  });

  factory CommentGetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CommentGetResponseDtoFromJson(json);

  static const toJsonFactory = _$CommentGetResponseDtoToJson;
  Map<String, dynamic> toJson() => _$CommentGetResponseDtoToJson(this);

  @JsonKey(name: 'elements', defaultValue: <String>[])
  final List<String> elements;
  static const fromJsonFactory = _$CommentGetResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentGetResponseDto &&
            (identical(other.elements, elements) ||
                const DeepCollectionEquality()
                    .equals(other.elements, elements)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(elements) ^ runtimeType.hashCode;
}

extension $CommentGetResponseDtoExtension on CommentGetResponseDto {
  CommentGetResponseDto copyWith({List<String>? elements}) {
    return CommentGetResponseDto(elements: elements ?? this.elements);
  }

  CommentGetResponseDto copyWithWrapped({Wrapped<List<String>>? elements}) {
    return CommentGetResponseDto(
        elements: (elements != null ? elements.value : this.elements));
  }
}

@JsonSerializable(explicitToJson: true)
class CommentPostDto {
  const CommentPostDto({
    required this.where,
    required this.body,
    this.parent,
  });

  factory CommentPostDto.fromJson(Map<String, dynamic> json) =>
      _$CommentPostDtoFromJson(json);

  static const toJsonFactory = _$CommentPostDtoToJson;
  Map<String, dynamic> toJson() => _$CommentPostDtoToJson(this);

  @JsonKey(name: 'where')
  final String where;
  @JsonKey(name: 'body')
  final String body;
  @JsonKey(name: 'parent')
  final double? parent;
  static const fromJsonFactory = _$CommentPostDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CommentPostDto &&
            (identical(other.where, where) ||
                const DeepCollectionEquality().equals(other.where, where)) &&
            (identical(other.body, body) ||
                const DeepCollectionEquality().equals(other.body, body)) &&
            (identical(other.parent, parent) ||
                const DeepCollectionEquality().equals(other.parent, parent)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(where) ^
      const DeepCollectionEquality().hash(body) ^
      const DeepCollectionEquality().hash(parent) ^
      runtimeType.hashCode;
}

extension $CommentPostDtoExtension on CommentPostDto {
  CommentPostDto copyWith({String? where, String? body, double? parent}) {
    return CommentPostDto(
        where: where ?? this.where,
        body: body ?? this.body,
        parent: parent ?? this.parent);
  }

  CommentPostDto copyWithWrapped(
      {Wrapped<String>? where,
      Wrapped<String>? body,
      Wrapped<double?>? parent}) {
    return CommentPostDto(
        where: (where != null ? where.value : this.where),
        body: (body != null ? body.value : this.body),
        parent: (parent != null ? parent.value : this.parent));
  }
}

@JsonSerializable(explicitToJson: true)
class UserRegisterDTO {
  const UserRegisterDTO({
    required this.userAppId,
  });

  factory UserRegisterDTO.fromJson(Map<String, dynamic> json) =>
      _$UserRegisterDTOFromJson(json);

  static const toJsonFactory = _$UserRegisterDTOToJson;
  Map<String, dynamic> toJson() => _$UserRegisterDTOToJson(this);

  @JsonKey(name: 'userAppId')
  final String userAppId;
  static const fromJsonFactory = _$UserRegisterDTOFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserRegisterDTO &&
            (identical(other.userAppId, userAppId) ||
                const DeepCollectionEquality()
                    .equals(other.userAppId, userAppId)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(userAppId) ^ runtimeType.hashCode;
}

extension $UserRegisterDTOExtension on UserRegisterDTO {
  UserRegisterDTO copyWith({String? userAppId}) {
    return UserRegisterDTO(userAppId: userAppId ?? this.userAppId);
  }

  UserRegisterDTO copyWithWrapped({Wrapped<String>? userAppId}) {
    return UserRegisterDTO(
        userAppId: (userAppId != null ? userAppId.value : this.userAppId));
  }
}

@JsonSerializable(explicitToJson: true)
class ListDiscordUserAppIdsResponseDto {
  const ListDiscordUserAppIdsResponseDto({
    required this.userAppIds,
  });

  factory ListDiscordUserAppIdsResponseDto.fromJson(
          Map<String, dynamic> json) =>
      _$ListDiscordUserAppIdsResponseDtoFromJson(json);

  static const toJsonFactory = _$ListDiscordUserAppIdsResponseDtoToJson;
  Map<String, dynamic> toJson() =>
      _$ListDiscordUserAppIdsResponseDtoToJson(this);

  @JsonKey(name: 'userAppIds', defaultValue: <String>[])
  final List<String> userAppIds;
  static const fromJsonFactory = _$ListDiscordUserAppIdsResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ListDiscordUserAppIdsResponseDto &&
            (identical(other.userAppIds, userAppIds) ||
                const DeepCollectionEquality()
                    .equals(other.userAppIds, userAppIds)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(userAppIds) ^ runtimeType.hashCode;
}

extension $ListDiscordUserAppIdsResponseDtoExtension
    on ListDiscordUserAppIdsResponseDto {
  ListDiscordUserAppIdsResponseDto copyWith({List<String>? userAppIds}) {
    return ListDiscordUserAppIdsResponseDto(
        userAppIds: userAppIds ?? this.userAppIds);
  }

  ListDiscordUserAppIdsResponseDto copyWithWrapped(
      {Wrapped<List<String>>? userAppIds}) {
    return ListDiscordUserAppIdsResponseDto(
        userAppIds: (userAppIds != null ? userAppIds.value : this.userAppIds));
  }
}

@JsonSerializable(explicitToJson: true)
class User {
  const User({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.userAppId,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  static const toJsonFactory = _$UserToJson;
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @JsonKey(name: 'id')
  final double id;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime updatedAt;
  @JsonKey(name: 'userAppId')
  final String userAppId;
  static const fromJsonFactory = _$UserFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is User &&
            (identical(other.id, id) ||
                const DeepCollectionEquality().equals(other.id, id)) &&
            (identical(other.createdAt, createdAt) ||
                const DeepCollectionEquality()
                    .equals(other.createdAt, createdAt)) &&
            (identical(other.updatedAt, updatedAt) ||
                const DeepCollectionEquality()
                    .equals(other.updatedAt, updatedAt)) &&
            (identical(other.userAppId, userAppId) ||
                const DeepCollectionEquality()
                    .equals(other.userAppId, userAppId)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(id) ^
      const DeepCollectionEquality().hash(createdAt) ^
      const DeepCollectionEquality().hash(updatedAt) ^
      const DeepCollectionEquality().hash(userAppId) ^
      runtimeType.hashCode;
}

extension $UserExtension on User {
  User copyWith(
      {double? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? userAppId}) {
    return User(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        userAppId: userAppId ?? this.userAppId);
  }

  User copyWithWrapped(
      {Wrapped<double>? id,
      Wrapped<DateTime>? createdAt,
      Wrapped<DateTime>? updatedAt,
      Wrapped<String>? userAppId}) {
    return User(
        id: (id != null ? id.value : this.id),
        createdAt: (createdAt != null ? createdAt.value : this.createdAt),
        updatedAt: (updatedAt != null ? updatedAt.value : this.updatedAt),
        userAppId: (userAppId != null ? userAppId.value : this.userAppId));
  }
}

@JsonSerializable(explicitToJson: true)
class Tokens {
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);

  static const toJsonFactory = _$TokensToJson;
  Map<String, dynamic> toJson() => _$TokensToJson(this);

  @JsonKey(name: 'accessToken')
  final String accessToken;
  @JsonKey(name: 'refreshToken')
  final String refreshToken;
  static const fromJsonFactory = _$TokensFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Tokens &&
            (identical(other.accessToken, accessToken) ||
                const DeepCollectionEquality()
                    .equals(other.accessToken, accessToken)) &&
            (identical(other.refreshToken, refreshToken) ||
                const DeepCollectionEquality()
                    .equals(other.refreshToken, refreshToken)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(accessToken) ^
      const DeepCollectionEquality().hash(refreshToken) ^
      runtimeType.hashCode;
}

extension $TokensExtension on Tokens {
  Tokens copyWith({String? accessToken, String? refreshToken}) {
    return Tokens(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken);
  }

  Tokens copyWithWrapped(
      {Wrapped<String>? accessToken, Wrapped<String>? refreshToken}) {
    return Tokens(
        accessToken:
            (accessToken != null ? accessToken.value : this.accessToken),
        refreshToken:
            (refreshToken != null ? refreshToken.value : this.refreshToken));
  }
}

@JsonSerializable(explicitToJson: true)
class ResLoginUser {
  const ResLoginUser();

  factory ResLoginUser.fromJson(Map<String, dynamic> json) =>
      _$ResLoginUserFromJson(json);

  static const toJsonFactory = _$ResLoginUserToJson;
  Map<String, dynamic> toJson() => _$ResLoginUserToJson(this);

  static const fromJsonFactory = _$ResLoginUserFromJson;

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode => runtimeType.hashCode;
}

@JsonSerializable(explicitToJson: true)
class ViewGetResponseDto {
  const ViewGetResponseDto({
    required this.result,
  });

  factory ViewGetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ViewGetResponseDtoFromJson(json);

  static const toJsonFactory = _$ViewGetResponseDtoToJson;
  Map<String, dynamic> toJson() => _$ViewGetResponseDtoToJson(this);

  @JsonKey(name: 'result', defaultValue: <String>[])
  final List<String> result;
  static const fromJsonFactory = _$ViewGetResponseDtoFromJson;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ViewGetResponseDto &&
            (identical(other.result, result) ||
                const DeepCollectionEquality().equals(other.result, result)));
  }

  @override
  String toString() => jsonEncode(this);

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(result) ^ runtimeType.hashCode;
}

extension $ViewGetResponseDtoExtension on ViewGetResponseDto {
  ViewGetResponseDto copyWith({List<String>? result}) {
    return ViewGetResponseDto(result: result ?? this.result);
  }

  ViewGetResponseDto copyWithWrapped({Wrapped<List<String>>? result}) {
    return ViewGetResponseDto(
        result: (result != null ? result.value : this.result));
  }
}

typedef $JsonFactory<T> = T Function(Map<String, dynamic> json);

class $CustomJsonDecoder {
  $CustomJsonDecoder(this.factories);

  final Map<Type, $JsonFactory> factories;

  dynamic decode<T>(dynamic entity) {
    if (entity is Iterable) {
      return _decodeList<T>(entity);
    }

    if (entity is T) {
      return entity;
    }

    if (isTypeOf<T, Map>()) {
      return entity;
    }

    if (isTypeOf<T, Iterable>()) {
      return entity;
    }

    if (entity is Map<String, dynamic>) {
      return _decodeMap<T>(entity);
    }

    return entity;
  }

  T _decodeMap<T>(Map<String, dynamic> values) {
    final jsonFactory = factories[T];
    if (jsonFactory == null || jsonFactory is! $JsonFactory<T>) {
      return throw "Could not find factory for type $T. Is '$T: $T.fromJsonFactory' included in the CustomJsonDecoder instance creation in bootstrapper.dart?";
    }

    return jsonFactory(values);
  }

  List<T> _decodeList<T>(Iterable values) =>
      values.where((v) => v != null).map<T>((v) => decode<T>(v) as T).toList();
}

class $JsonSerializableConverter extends chopper.JsonConverter {
  @override
  FutureOr<chopper.Response<ResultType>> convertResponse<ResultType, Item>(
      chopper.Response response) async {
    if (response.bodyString.isEmpty) {
      // In rare cases, when let's say 204 (no content) is returned -
      // we cannot decode the missing json with the result type specified
      return chopper.Response(response.base, null, error: response.error);
    }

    if (ResultType == String) {
      return response.copyWith();
    }

    if (ResultType == DateTime) {
      return response.copyWith(
          body: DateTime.parse((response.body as String).replaceAll('"', ''))
              as ResultType);
    }

    final jsonRes = await super.convertResponse(response);
    return jsonRes.copyWith<ResultType>(
        body: $jsonDecoder.decode<Item>(jsonRes.body) as ResultType);
  }
}

final $jsonDecoder = $CustomJsonDecoder(generatedMapping);

// ignore: unused_element
String? _dateToJson(DateTime? date) {
  if (date == null) {
    return null;
  }

  final year = date.year.toString();
  final month = date.month < 10 ? '0${date.month}' : date.month.toString();
  final day = date.day < 10 ? '0${date.day}' : date.day.toString();

  return '$year-$month-$day';
}

class Wrapped<T> {
  final T value;
  const Wrapped.value(this.value);
}
