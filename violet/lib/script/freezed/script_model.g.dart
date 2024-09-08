// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScriptImageListImpl _$$ScriptImageListImplFromJson(
        Map<String, dynamic> json) =>
    _$ScriptImageListImpl(
      result:
          (json['result'] as List<dynamic>).map((e) => e as String).toList(),
      btresult:
          (json['btresult'] as List<dynamic>).map((e) => e as String).toList(),
      stresult:
          (json['stresult'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$ScriptImageListImplToJson(
        _$ScriptImageListImpl instance) =>
    <String, dynamic>{
      'result': instance.result,
      'btresult': instance.btresult,
      'stresult': instance.stresult,
    };
