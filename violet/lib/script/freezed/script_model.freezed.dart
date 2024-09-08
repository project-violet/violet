// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'script_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScriptImageList _$ScriptImageListFromJson(Map<String, dynamic> json) {
  return _ScriptImageList.fromJson(json);
}

/// @nodoc
mixin _$ScriptImageList {
  List<String> get result => throw _privateConstructorUsedError;
  List<String> get btresult => throw _privateConstructorUsedError;
  List<String> get stresult => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ScriptImageListCopyWith<ScriptImageList> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScriptImageListCopyWith<$Res> {
  factory $ScriptImageListCopyWith(
          ScriptImageList value, $Res Function(ScriptImageList) then) =
      _$ScriptImageListCopyWithImpl<$Res, ScriptImageList>;
  @useResult
  $Res call(
      {List<String> result, List<String> btresult, List<String> stresult});
}

/// @nodoc
class _$ScriptImageListCopyWithImpl<$Res, $Val extends ScriptImageList>
    implements $ScriptImageListCopyWith<$Res> {
  _$ScriptImageListCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? result = null,
    Object? btresult = null,
    Object? stresult = null,
  }) {
    return _then(_value.copyWith(
      result: null == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as List<String>,
      btresult: null == btresult
          ? _value.btresult
          : btresult // ignore: cast_nullable_to_non_nullable
              as List<String>,
      stresult: null == stresult
          ? _value.stresult
          : stresult // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ScriptImageListImplCopyWith<$Res>
    implements $ScriptImageListCopyWith<$Res> {
  factory _$$ScriptImageListImplCopyWith(_$ScriptImageListImpl value,
          $Res Function(_$ScriptImageListImpl) then) =
      __$$ScriptImageListImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String> result, List<String> btresult, List<String> stresult});
}

/// @nodoc
class __$$ScriptImageListImplCopyWithImpl<$Res>
    extends _$ScriptImageListCopyWithImpl<$Res, _$ScriptImageListImpl>
    implements _$$ScriptImageListImplCopyWith<$Res> {
  __$$ScriptImageListImplCopyWithImpl(
      _$ScriptImageListImpl _value, $Res Function(_$ScriptImageListImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? result = null,
    Object? btresult = null,
    Object? stresult = null,
  }) {
    return _then(_$ScriptImageListImpl(
      result: null == result
          ? _value._result
          : result // ignore: cast_nullable_to_non_nullable
              as List<String>,
      btresult: null == btresult
          ? _value._btresult
          : btresult // ignore: cast_nullable_to_non_nullable
              as List<String>,
      stresult: null == stresult
          ? _value._stresult
          : stresult // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScriptImageListImpl
    with DiagnosticableTreeMixin
    implements _ScriptImageList {
  const _$ScriptImageListImpl(
      {required final List<String> result,
      required final List<String> btresult,
      required final List<String> stresult})
      : _result = result,
        _btresult = btresult,
        _stresult = stresult;

  factory _$ScriptImageListImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScriptImageListImplFromJson(json);

  final List<String> _result;
  @override
  List<String> get result {
    if (_result is EqualUnmodifiableListView) return _result;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_result);
  }

  final List<String> _btresult;
  @override
  List<String> get btresult {
    if (_btresult is EqualUnmodifiableListView) return _btresult;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_btresult);
  }

  final List<String> _stresult;
  @override
  List<String> get stresult {
    if (_stresult is EqualUnmodifiableListView) return _stresult;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stresult);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ScriptImageList(result: $result, btresult: $btresult, stresult: $stresult)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ScriptImageList'))
      ..add(DiagnosticsProperty('result', result))
      ..add(DiagnosticsProperty('btresult', btresult))
      ..add(DiagnosticsProperty('stresult', stresult));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScriptImageListImpl &&
            const DeepCollectionEquality().equals(other._result, _result) &&
            const DeepCollectionEquality().equals(other._btresult, _btresult) &&
            const DeepCollectionEquality().equals(other._stresult, _stresult));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_result),
      const DeepCollectionEquality().hash(_btresult),
      const DeepCollectionEquality().hash(_stresult));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ScriptImageListImplCopyWith<_$ScriptImageListImpl> get copyWith =>
      __$$ScriptImageListImplCopyWithImpl<_$ScriptImageListImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScriptImageListImplToJson(
      this,
    );
  }
}

abstract class _ScriptImageList implements ScriptImageList {
  const factory _ScriptImageList(
      {required final List<String> result,
      required final List<String> btresult,
      required final List<String> stresult}) = _$ScriptImageListImpl;

  factory _ScriptImageList.fromJson(Map<String, dynamic> json) =
      _$ScriptImageListImpl.fromJson;

  @override
  List<String> get result;
  @override
  List<String> get btresult;
  @override
  List<String> get stresult;
  @override
  @JsonKey(ignore: true)
  _$$ScriptImageListImplCopyWith<_$ScriptImageListImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
