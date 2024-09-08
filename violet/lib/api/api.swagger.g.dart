// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api.swagger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentGetDto _$CommentGetDtoFromJson(Map<String, dynamic> json) =>
    CommentGetDto(
      where: json['where'] as String,
    );

Map<String, dynamic> _$CommentGetDtoToJson(CommentGetDto instance) =>
    <String, dynamic>{
      'where': instance.where,
    };

CommentPostDto _$CommentPostDtoFromJson(Map<String, dynamic> json) =>
    CommentPostDto(
      where: json['where'] as String,
      body: json['body'] as String,
      parent: (json['parent'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CommentPostDtoToJson(CommentPostDto instance) =>
    <String, dynamic>{
      'where': instance.where,
      'body': instance.body,
      'parent': instance.parent,
    };

UserRegisterDTO _$UserRegisterDTOFromJson(Map<String, dynamic> json) =>
    UserRegisterDTO(
      userAppId: json['userAppId'] as String,
    );

Map<String, dynamic> _$UserRegisterDTOToJson(UserRegisterDTO instance) =>
    <String, dynamic>{
      'userAppId': instance.userAppId,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: (json['id'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userAppId: json['userAppId'] as String,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userAppId': instance.userAppId,
    };

Tokens _$TokensFromJson(Map<String, dynamic> json) => Tokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );

Map<String, dynamic> _$TokensToJson(Tokens instance) => <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
    };

ViewGetResponseDto _$ViewGetResponseDtoFromJson(Map<String, dynamic> json) =>
    ViewGetResponseDto(
      result: (json['result'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$ViewGetResponseDtoToJson(ViewGetResponseDto instance) =>
    <String, dynamic>{
      'result': instance.result,
    };
