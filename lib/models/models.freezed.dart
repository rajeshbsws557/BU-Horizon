// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$QuickAction {
  String get title => throw _privateConstructorUsedError;
  String get subtitle => throw _privateConstructorUsedError;
  IconData get icon => throw _privateConstructorUsedError;
  Color get color => throw _privateConstructorUsedError;
  String get route => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $QuickActionCopyWith<QuickAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuickActionCopyWith<$Res> {
  factory $QuickActionCopyWith(
          QuickAction value, $Res Function(QuickAction) then) =
      _$QuickActionCopyWithImpl<$Res, QuickAction>;
  @useResult
  $Res call(
      {String title,
      String subtitle,
      IconData icon,
      Color color,
      String route});
}

/// @nodoc
class _$QuickActionCopyWithImpl<$Res, $Val extends QuickAction>
    implements $QuickActionCopyWith<$Res> {
  _$QuickActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? icon = null,
    Object? color = null,
    Object? route = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
      route: null == route
          ? _value.route
          : route // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuickActionImplCopyWith<$Res>
    implements $QuickActionCopyWith<$Res> {
  factory _$$QuickActionImplCopyWith(
          _$QuickActionImpl value, $Res Function(_$QuickActionImpl) then) =
      __$$QuickActionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      String subtitle,
      IconData icon,
      Color color,
      String route});
}

/// @nodoc
class __$$QuickActionImplCopyWithImpl<$Res>
    extends _$QuickActionCopyWithImpl<$Res, _$QuickActionImpl>
    implements _$$QuickActionImplCopyWith<$Res> {
  __$$QuickActionImplCopyWithImpl(
      _$QuickActionImpl _value, $Res Function(_$QuickActionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? icon = null,
    Object? color = null,
    Object? route = null,
  }) {
    return _then(_$QuickActionImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
      route: null == route
          ? _value.route
          : route // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$QuickActionImpl implements _QuickAction {
  const _$QuickActionImpl(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.route});

  @override
  final String title;
  @override
  final String subtitle;
  @override
  final IconData icon;
  @override
  final Color color;
  @override
  final String route;

  @override
  String toString() {
    return 'QuickAction(title: $title, subtitle: $subtitle, icon: $icon, color: $color, route: $route)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuickActionImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.route, route) || other.route == route));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, title, subtitle, icon, color, route);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$QuickActionImplCopyWith<_$QuickActionImpl> get copyWith =>
      __$$QuickActionImplCopyWithImpl<_$QuickActionImpl>(this, _$identity);
}

abstract class _QuickAction implements QuickAction {
  const factory _QuickAction(
      {required final String title,
      required final String subtitle,
      required final IconData icon,
      required final Color color,
      required final String route}) = _$QuickActionImpl;

  @override
  String get title;
  @override
  String get subtitle;
  @override
  IconData get icon;
  @override
  Color get color;
  @override
  String get route;
  @override
  @JsonKey(ignore: true)
  _$$QuickActionImplCopyWith<_$QuickActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) {
  return _BusRoute.fromJson(json);
}

/// @nodoc
mixin _$BusRoute {
  String get name => throw _privateConstructorUsedError;
  String get window => throw _privateConstructorUsedError;
  String get frequency => throw _privateConstructorUsedError;
  String get nextBus => throw _privateConstructorUsedError;
  bool get favorite => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BusRouteCopyWith<BusRoute> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusRouteCopyWith<$Res> {
  factory $BusRouteCopyWith(BusRoute value, $Res Function(BusRoute) then) =
      _$BusRouteCopyWithImpl<$Res, BusRoute>;
  @useResult
  $Res call(
      {String name,
      String window,
      String frequency,
      String nextBus,
      bool favorite});
}

/// @nodoc
class _$BusRouteCopyWithImpl<$Res, $Val extends BusRoute>
    implements $BusRouteCopyWith<$Res> {
  _$BusRouteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? window = null,
    Object? frequency = null,
    Object? nextBus = null,
    Object? favorite = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      window: null == window
          ? _value.window
          : window // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      nextBus: null == nextBus
          ? _value.nextBus
          : nextBus // ignore: cast_nullable_to_non_nullable
              as String,
      favorite: null == favorite
          ? _value.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BusRouteImplCopyWith<$Res>
    implements $BusRouteCopyWith<$Res> {
  factory _$$BusRouteImplCopyWith(
          _$BusRouteImpl value, $Res Function(_$BusRouteImpl) then) =
      __$$BusRouteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String window,
      String frequency,
      String nextBus,
      bool favorite});
}

/// @nodoc
class __$$BusRouteImplCopyWithImpl<$Res>
    extends _$BusRouteCopyWithImpl<$Res, _$BusRouteImpl>
    implements _$$BusRouteImplCopyWith<$Res> {
  __$$BusRouteImplCopyWithImpl(
      _$BusRouteImpl _value, $Res Function(_$BusRouteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? window = null,
    Object? frequency = null,
    Object? nextBus = null,
    Object? favorite = null,
  }) {
    return _then(_$BusRouteImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      window: null == window
          ? _value.window
          : window // ignore: cast_nullable_to_non_nullable
              as String,
      frequency: null == frequency
          ? _value.frequency
          : frequency // ignore: cast_nullable_to_non_nullable
              as String,
      nextBus: null == nextBus
          ? _value.nextBus
          : nextBus // ignore: cast_nullable_to_non_nullable
              as String,
      favorite: null == favorite
          ? _value.favorite
          : favorite // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BusRouteImpl implements _BusRoute {
  const _$BusRouteImpl(
      {required this.name,
      required this.window,
      required this.frequency,
      required this.nextBus,
      this.favorite = false});

  factory _$BusRouteImpl.fromJson(Map<String, dynamic> json) =>
      _$$BusRouteImplFromJson(json);

  @override
  final String name;
  @override
  final String window;
  @override
  final String frequency;
  @override
  final String nextBus;
  @override
  @JsonKey()
  final bool favorite;

  @override
  String toString() {
    return 'BusRoute(name: $name, window: $window, frequency: $frequency, nextBus: $nextBus, favorite: $favorite)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusRouteImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.window, window) || other.window == window) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency) &&
            (identical(other.nextBus, nextBus) || other.nextBus == nextBus) &&
            (identical(other.favorite, favorite) ||
                other.favorite == favorite));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, window, frequency, nextBus, favorite);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BusRouteImplCopyWith<_$BusRouteImpl> get copyWith =>
      __$$BusRouteImplCopyWithImpl<_$BusRouteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BusRouteImplToJson(
      this,
    );
  }
}

abstract class _BusRoute implements BusRoute {
  const factory _BusRoute(
      {required final String name,
      required final String window,
      required final String frequency,
      required final String nextBus,
      final bool favorite}) = _$BusRouteImpl;

  factory _BusRoute.fromJson(Map<String, dynamic> json) =
      _$BusRouteImpl.fromJson;

  @override
  String get name;
  @override
  String get window;
  @override
  String get frequency;
  @override
  String get nextBus;
  @override
  bool get favorite;
  @override
  @JsonKey(ignore: true)
  _$$BusRouteImplCopyWith<_$BusRouteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ClassNotice {
  String get title => throw _privateConstructorUsedError;
  String get subtitle => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;
  NoticeCategory get category => throw _privateConstructorUsedError;
  IconData get icon => throw _privateConstructorUsedError;
  Color get color => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ClassNoticeCopyWith<ClassNotice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClassNoticeCopyWith<$Res> {
  factory $ClassNoticeCopyWith(
          ClassNotice value, $Res Function(ClassNotice) then) =
      _$ClassNoticeCopyWithImpl<$Res, ClassNotice>;
  @useResult
  $Res call(
      {String title,
      String subtitle,
      String time,
      NoticeCategory category,
      IconData icon,
      Color color});
}

/// @nodoc
class _$ClassNoticeCopyWithImpl<$Res, $Val extends ClassNotice>
    implements $ClassNoticeCopyWith<$Res> {
  _$ClassNoticeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? time = null,
    Object? category = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as NoticeCategory,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClassNoticeImplCopyWith<$Res>
    implements $ClassNoticeCopyWith<$Res> {
  factory _$$ClassNoticeImplCopyWith(
          _$ClassNoticeImpl value, $Res Function(_$ClassNoticeImpl) then) =
      __$$ClassNoticeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      String subtitle,
      String time,
      NoticeCategory category,
      IconData icon,
      Color color});
}

/// @nodoc
class __$$ClassNoticeImplCopyWithImpl<$Res>
    extends _$ClassNoticeCopyWithImpl<$Res, _$ClassNoticeImpl>
    implements _$$ClassNoticeImplCopyWith<$Res> {
  __$$ClassNoticeImplCopyWithImpl(
      _$ClassNoticeImpl _value, $Res Function(_$ClassNoticeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? time = null,
    Object? category = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(_$ClassNoticeImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as NoticeCategory,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
    ));
  }
}

/// @nodoc

class _$ClassNoticeImpl implements _ClassNotice {
  const _$ClassNoticeImpl(
      {required this.title,
      required this.subtitle,
      required this.time,
      required this.category,
      required this.icon,
      required this.color});

  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String time;
  @override
  final NoticeCategory category;
  @override
  final IconData icon;
  @override
  final Color color;

  @override
  String toString() {
    return 'ClassNotice(title: $title, subtitle: $subtitle, time: $time, category: $category, icon: $icon, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClassNoticeImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, title, subtitle, time, category, icon, color);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ClassNoticeImplCopyWith<_$ClassNoticeImpl> get copyWith =>
      __$$ClassNoticeImplCopyWithImpl<_$ClassNoticeImpl>(this, _$identity);
}

abstract class _ClassNotice implements ClassNotice {
  const factory _ClassNotice(
      {required final String title,
      required final String subtitle,
      required final String time,
      required final NoticeCategory category,
      required final IconData icon,
      required final Color color}) = _$ClassNoticeImpl;

  @override
  String get title;
  @override
  String get subtitle;
  @override
  String get time;
  @override
  NoticeCategory get category;
  @override
  IconData get icon;
  @override
  Color get color;
  @override
  @JsonKey(ignore: true)
  _$$ClassNoticeImplCopyWith<_$ClassNoticeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Person {
  String get name => throw _privateConstructorUsedError;
  String get department => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PersonCopyWith<Person> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonCopyWith<$Res> {
  factory $PersonCopyWith(Person value, $Res Function(Person) then) =
      _$PersonCopyWithImpl<$Res, Person>;
  @useResult
  $Res call({String name, String department, String email});
}

/// @nodoc
class _$PersonCopyWithImpl<$Res, $Val extends Person>
    implements $PersonCopyWith<$Res> {
  _$PersonCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? department = null,
    Object? email = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PersonImplCopyWith<$Res> implements $PersonCopyWith<$Res> {
  factory _$$PersonImplCopyWith(
          _$PersonImpl value, $Res Function(_$PersonImpl) then) =
      __$$PersonImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String department, String email});
}

/// @nodoc
class __$$PersonImplCopyWithImpl<$Res>
    extends _$PersonCopyWithImpl<$Res, _$PersonImpl>
    implements _$$PersonImplCopyWith<$Res> {
  __$$PersonImplCopyWithImpl(
      _$PersonImpl _value, $Res Function(_$PersonImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? department = null,
    Object? email = null,
  }) {
    return _then(_$PersonImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$PersonImpl extends _Person {
  const _$PersonImpl(
      {required this.name, required this.department, required this.email})
      : super._();

  @override
  final String name;
  @override
  final String department;
  @override
  final String email;

  @override
  String toString() {
    return 'Person(name: $name, department: $department, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.email, email) || other.email == email));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, department, email);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonImplCopyWith<_$PersonImpl> get copyWith =>
      __$$PersonImplCopyWithImpl<_$PersonImpl>(this, _$identity);
}

abstract class _Person extends Person {
  const factory _Person(
      {required final String name,
      required final String department,
      required final String email}) = _$PersonImpl;
  const _Person._() : super._();

  @override
  String get name;
  @override
  String get department;
  @override
  String get email;
  @override
  @JsonKey(ignore: true)
  _$$PersonImplCopyWith<_$PersonImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BloodNeed {
  int get units => throw _privateConstructorUsedError;
  BloodGroup get group => throw _privateConstructorUsedError;
  String get contact => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $BloodNeedCopyWith<BloodNeed> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BloodNeedCopyWith<$Res> {
  factory $BloodNeedCopyWith(BloodNeed value, $Res Function(BloodNeed) then) =
      _$BloodNeedCopyWithImpl<$Res, BloodNeed>;
  @useResult
  $Res call(
      {int units,
      BloodGroup group,
      String contact,
      String location,
      String time});
}

/// @nodoc
class _$BloodNeedCopyWithImpl<$Res, $Val extends BloodNeed>
    implements $BloodNeedCopyWith<$Res> {
  _$BloodNeedCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? units = null,
    Object? group = null,
    Object? contact = null,
    Object? location = null,
    Object? time = null,
  }) {
    return _then(_value.copyWith(
      units: null == units
          ? _value.units
          : units // ignore: cast_nullable_to_non_nullable
              as int,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as BloodGroup,
      contact: null == contact
          ? _value.contact
          : contact // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BloodNeedImplCopyWith<$Res>
    implements $BloodNeedCopyWith<$Res> {
  factory _$$BloodNeedImplCopyWith(
          _$BloodNeedImpl value, $Res Function(_$BloodNeedImpl) then) =
      __$$BloodNeedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int units,
      BloodGroup group,
      String contact,
      String location,
      String time});
}

/// @nodoc
class __$$BloodNeedImplCopyWithImpl<$Res>
    extends _$BloodNeedCopyWithImpl<$Res, _$BloodNeedImpl>
    implements _$$BloodNeedImplCopyWith<$Res> {
  __$$BloodNeedImplCopyWithImpl(
      _$BloodNeedImpl _value, $Res Function(_$BloodNeedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? units = null,
    Object? group = null,
    Object? contact = null,
    Object? location = null,
    Object? time = null,
  }) {
    return _then(_$BloodNeedImpl(
      units: null == units
          ? _value.units
          : units // ignore: cast_nullable_to_non_nullable
              as int,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as BloodGroup,
      contact: null == contact
          ? _value.contact
          : contact // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BloodNeedImpl implements _BloodNeed {
  const _$BloodNeedImpl(
      {required this.units,
      required this.group,
      required this.contact,
      required this.location,
      required this.time});

  @override
  final int units;
  @override
  final BloodGroup group;
  @override
  final String contact;
  @override
  final String location;
  @override
  final String time;

  @override
  String toString() {
    return 'BloodNeed(units: $units, group: $group, contact: $contact, location: $location, time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BloodNeedImpl &&
            (identical(other.units, units) || other.units == units) &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.contact, contact) || other.contact == contact) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.time, time) || other.time == time));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, units, group, contact, location, time);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BloodNeedImplCopyWith<_$BloodNeedImpl> get copyWith =>
      __$$BloodNeedImplCopyWithImpl<_$BloodNeedImpl>(this, _$identity);
}

abstract class _BloodNeed implements BloodNeed {
  const factory _BloodNeed(
      {required final int units,
      required final BloodGroup group,
      required final String contact,
      required final String location,
      required final String time}) = _$BloodNeedImpl;

  @override
  int get units;
  @override
  BloodGroup get group;
  @override
  String get contact;
  @override
  String get location;
  @override
  String get time;
  @override
  @JsonKey(ignore: true)
  _$$BloodNeedImplCopyWith<_$BloodNeedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BloodRequest {
  BloodGroup get group => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $BloodRequestCopyWith<BloodRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BloodRequestCopyWith<$Res> {
  factory $BloodRequestCopyWith(
          BloodRequest value, $Res Function(BloodRequest) then) =
      _$BloodRequestCopyWithImpl<$Res, BloodRequest>;
  @useResult
  $Res call({BloodGroup group, String location, String time});
}

/// @nodoc
class _$BloodRequestCopyWithImpl<$Res, $Val extends BloodRequest>
    implements $BloodRequestCopyWith<$Res> {
  _$BloodRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? group = null,
    Object? location = null,
    Object? time = null,
  }) {
    return _then(_value.copyWith(
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as BloodGroup,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BloodRequestImplCopyWith<$Res>
    implements $BloodRequestCopyWith<$Res> {
  factory _$$BloodRequestImplCopyWith(
          _$BloodRequestImpl value, $Res Function(_$BloodRequestImpl) then) =
      __$$BloodRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({BloodGroup group, String location, String time});
}

/// @nodoc
class __$$BloodRequestImplCopyWithImpl<$Res>
    extends _$BloodRequestCopyWithImpl<$Res, _$BloodRequestImpl>
    implements _$$BloodRequestImplCopyWith<$Res> {
  __$$BloodRequestImplCopyWithImpl(
      _$BloodRequestImpl _value, $Res Function(_$BloodRequestImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? group = null,
    Object? location = null,
    Object? time = null,
  }) {
    return _then(_$BloodRequestImpl(
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as BloodGroup,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BloodRequestImpl implements _BloodRequest {
  const _$BloodRequestImpl(
      {required this.group, required this.location, required this.time});

  @override
  final BloodGroup group;
  @override
  final String location;
  @override
  final String time;

  @override
  String toString() {
    return 'BloodRequest(group: $group, location: $location, time: $time)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BloodRequestImpl &&
            (identical(other.group, group) || other.group == group) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.time, time) || other.time == time));
  }

  @override
  int get hashCode => Object.hash(runtimeType, group, location, time);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BloodRequestImplCopyWith<_$BloodRequestImpl> get copyWith =>
      __$$BloodRequestImplCopyWithImpl<_$BloodRequestImpl>(this, _$identity);
}

abstract class _BloodRequest implements BloodRequest {
  const factory _BloodRequest(
      {required final BloodGroup group,
      required final String location,
      required final String time}) = _$BloodRequestImpl;

  @override
  BloodGroup get group;
  @override
  String get location;
  @override
  String get time;
  @override
  @JsonKey(ignore: true)
  _$$BloodRequestImplCopyWith<_$BloodRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LostFoundItem {
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get location => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;
  bool get isLost => throw _privateConstructorUsedError;
  IconData get icon => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $LostFoundItemCopyWith<LostFoundItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LostFoundItemCopyWith<$Res> {
  factory $LostFoundItemCopyWith(
          LostFoundItem value, $Res Function(LostFoundItem) then) =
      _$LostFoundItemCopyWithImpl<$Res, LostFoundItem>;
  @useResult
  $Res call(
      {String title,
      String description,
      String location,
      String time,
      bool isLost,
      IconData icon});
}

/// @nodoc
class _$LostFoundItemCopyWithImpl<$Res, $Val extends LostFoundItem>
    implements $LostFoundItemCopyWith<$Res> {
  _$LostFoundItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? description = null,
    Object? location = null,
    Object? time = null,
    Object? isLost = null,
    Object? icon = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      isLost: null == isLost
          ? _value.isLost
          : isLost // ignore: cast_nullable_to_non_nullable
              as bool,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LostFoundItemImplCopyWith<$Res>
    implements $LostFoundItemCopyWith<$Res> {
  factory _$$LostFoundItemImplCopyWith(
          _$LostFoundItemImpl value, $Res Function(_$LostFoundItemImpl) then) =
      __$$LostFoundItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      String description,
      String location,
      String time,
      bool isLost,
      IconData icon});
}

/// @nodoc
class __$$LostFoundItemImplCopyWithImpl<$Res>
    extends _$LostFoundItemCopyWithImpl<$Res, _$LostFoundItemImpl>
    implements _$$LostFoundItemImplCopyWith<$Res> {
  __$$LostFoundItemImplCopyWithImpl(
      _$LostFoundItemImpl _value, $Res Function(_$LostFoundItemImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? description = null,
    Object? location = null,
    Object? time = null,
    Object? isLost = null,
    Object? icon = null,
  }) {
    return _then(_$LostFoundItemImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      isLost: null == isLost
          ? _value.isLost
          : isLost // ignore: cast_nullable_to_non_nullable
              as bool,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as IconData,
    ));
  }
}

/// @nodoc

class _$LostFoundItemImpl implements _LostFoundItem {
  const _$LostFoundItemImpl(
      {required this.title,
      required this.description,
      required this.location,
      required this.time,
      required this.isLost,
      required this.icon});

  @override
  final String title;
  @override
  final String description;
  @override
  final String location;
  @override
  final String time;
  @override
  final bool isLost;
  @override
  final IconData icon;

  @override
  String toString() {
    return 'LostFoundItem(title: $title, description: $description, location: $location, time: $time, isLost: $isLost, icon: $icon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LostFoundItemImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.isLost, isLost) || other.isLost == isLost) &&
            (identical(other.icon, icon) || other.icon == icon));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, title, description, location, time, isLost, icon);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LostFoundItemImplCopyWith<_$LostFoundItemImpl> get copyWith =>
      __$$LostFoundItemImplCopyWithImpl<_$LostFoundItemImpl>(this, _$identity);
}

abstract class _LostFoundItem implements LostFoundItem {
  const factory _LostFoundItem(
      {required final String title,
      required final String description,
      required final String location,
      required final String time,
      required final bool isLost,
      required final IconData icon}) = _$LostFoundItemImpl;

  @override
  String get title;
  @override
  String get description;
  @override
  String get location;
  @override
  String get time;
  @override
  bool get isLost;
  @override
  IconData get icon;
  @override
  @JsonKey(ignore: true)
  _$$LostFoundItemImplCopyWith<_$LostFoundItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AttendanceClass {
  String get subject => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;
  AttendanceStatus get status => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AttendanceClassCopyWith<AttendanceClass> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceClassCopyWith<$Res> {
  factory $AttendanceClassCopyWith(
          AttendanceClass value, $Res Function(AttendanceClass) then) =
      _$AttendanceClassCopyWithImpl<$Res, AttendanceClass>;
  @useResult
  $Res call({String subject, String time, AttendanceStatus status});
}

/// @nodoc
class _$AttendanceClassCopyWithImpl<$Res, $Val extends AttendanceClass>
    implements $AttendanceClassCopyWith<$Res> {
  _$AttendanceClassCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subject = null,
    Object? time = null,
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendanceStatus,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AttendanceClassImplCopyWith<$Res>
    implements $AttendanceClassCopyWith<$Res> {
  factory _$$AttendanceClassImplCopyWith(_$AttendanceClassImpl value,
          $Res Function(_$AttendanceClassImpl) then) =
      __$$AttendanceClassImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String subject, String time, AttendanceStatus status});
}

/// @nodoc
class __$$AttendanceClassImplCopyWithImpl<$Res>
    extends _$AttendanceClassCopyWithImpl<$Res, _$AttendanceClassImpl>
    implements _$$AttendanceClassImplCopyWith<$Res> {
  __$$AttendanceClassImplCopyWithImpl(
      _$AttendanceClassImpl _value, $Res Function(_$AttendanceClassImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subject = null,
    Object? time = null,
    Object? status = null,
  }) {
    return _then(_$AttendanceClassImpl(
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AttendanceStatus,
    ));
  }
}

/// @nodoc

class _$AttendanceClassImpl implements _AttendanceClass {
  const _$AttendanceClassImpl(
      {required this.subject, required this.time, required this.status});

  @override
  final String subject;
  @override
  final String time;
  @override
  final AttendanceStatus status;

  @override
  String toString() {
    return 'AttendanceClass(subject: $subject, time: $time, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceClassImpl &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(runtimeType, subject, time, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceClassImplCopyWith<_$AttendanceClassImpl> get copyWith =>
      __$$AttendanceClassImplCopyWithImpl<_$AttendanceClassImpl>(
          this, _$identity);
}

abstract class _AttendanceClass implements AttendanceClass {
  const factory _AttendanceClass(
      {required final String subject,
      required final String time,
      required final AttendanceStatus status}) = _$AttendanceClassImpl;

  @override
  String get subject;
  @override
  String get time;
  @override
  AttendanceStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$AttendanceClassImplCopyWith<_$AttendanceClassImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AlertItem {
  String get title => throw _privateConstructorUsedError;
  String get subtitle => throw _privateConstructorUsedError;
  String get time => throw _privateConstructorUsedError;
  AlertType get type => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AlertItemCopyWith<AlertItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AlertItemCopyWith<$Res> {
  factory $AlertItemCopyWith(AlertItem value, $Res Function(AlertItem) then) =
      _$AlertItemCopyWithImpl<$Res, AlertItem>;
  @useResult
  $Res call({String title, String subtitle, String time, AlertType type});
}

/// @nodoc
class _$AlertItemCopyWithImpl<$Res, $Val extends AlertItem>
    implements $AlertItemCopyWith<$Res> {
  _$AlertItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? time = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AlertType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AlertItemImplCopyWith<$Res>
    implements $AlertItemCopyWith<$Res> {
  factory _$$AlertItemImplCopyWith(
          _$AlertItemImpl value, $Res Function(_$AlertItemImpl) then) =
      __$$AlertItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String subtitle, String time, AlertType type});
}

/// @nodoc
class __$$AlertItemImplCopyWithImpl<$Res>
    extends _$AlertItemCopyWithImpl<$Res, _$AlertItemImpl>
    implements _$$AlertItemImplCopyWith<$Res> {
  __$$AlertItemImplCopyWithImpl(
      _$AlertItemImpl _value, $Res Function(_$AlertItemImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? subtitle = null,
    Object? time = null,
    Object? type = null,
  }) {
    return _then(_$AlertItemImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      time: null == time
          ? _value.time
          : time // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AlertType,
    ));
  }
}

/// @nodoc

class _$AlertItemImpl implements _AlertItem {
  const _$AlertItemImpl(
      {required this.title,
      required this.subtitle,
      required this.time,
      required this.type});

  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String time;
  @override
  final AlertType type;

  @override
  String toString() {
    return 'AlertItem(title: $title, subtitle: $subtitle, time: $time, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AlertItemImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.time, time) || other.time == time) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode => Object.hash(runtimeType, title, subtitle, time, type);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AlertItemImplCopyWith<_$AlertItemImpl> get copyWith =>
      __$$AlertItemImplCopyWithImpl<_$AlertItemImpl>(this, _$identity);
}

abstract class _AlertItem implements AlertItem {
  const factory _AlertItem(
      {required final String title,
      required final String subtitle,
      required final String time,
      required final AlertType type}) = _$AlertItemImpl;

  @override
  String get title;
  @override
  String get subtitle;
  @override
  String get time;
  @override
  AlertType get type;
  @override
  @JsonKey(ignore: true)
  _$$AlertItemImplCopyWith<_$AlertItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$StudentProfile {
  String get name => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;
  String get department => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $StudentProfileCopyWith<StudentProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentProfileCopyWith<$Res> {
  factory $StudentProfileCopyWith(
          StudentProfile value, $Res Function(StudentProfile) then) =
      _$StudentProfileCopyWithImpl<$Res, StudentProfile>;
  @useResult
  $Res call({String name, String id, String department, String email});
}

/// @nodoc
class _$StudentProfileCopyWithImpl<$Res, $Val extends StudentProfile>
    implements $StudentProfileCopyWith<$Res> {
  _$StudentProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? id = null,
    Object? department = null,
    Object? email = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentProfileImplCopyWith<$Res>
    implements $StudentProfileCopyWith<$Res> {
  factory _$$StudentProfileImplCopyWith(_$StudentProfileImpl value,
          $Res Function(_$StudentProfileImpl) then) =
      __$$StudentProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String id, String department, String email});
}

/// @nodoc
class __$$StudentProfileImplCopyWithImpl<$Res>
    extends _$StudentProfileCopyWithImpl<$Res, _$StudentProfileImpl>
    implements _$$StudentProfileImplCopyWith<$Res> {
  __$$StudentProfileImplCopyWithImpl(
      _$StudentProfileImpl _value, $Res Function(_$StudentProfileImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? id = null,
    Object? department = null,
    Object? email = null,
  }) {
    return _then(_$StudentProfileImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$StudentProfileImpl implements _StudentProfile {
  const _$StudentProfileImpl(
      {required this.name,
      required this.id,
      required this.department,
      required this.email});

  @override
  final String name;
  @override
  final String id;
  @override
  final String department;
  @override
  final String email;

  @override
  String toString() {
    return 'StudentProfile(name: $name, id: $id, department: $department, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentProfileImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.email, email) || other.email == email));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, id, department, email);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentProfileImplCopyWith<_$StudentProfileImpl> get copyWith =>
      __$$StudentProfileImplCopyWithImpl<_$StudentProfileImpl>(
          this, _$identity);
}

abstract class _StudentProfile implements StudentProfile {
  const factory _StudentProfile(
      {required final String name,
      required final String id,
      required final String department,
      required final String email}) = _$StudentProfileImpl;

  @override
  String get name;
  @override
  String get id;
  @override
  String get department;
  @override
  String get email;
  @override
  @JsonKey(ignore: true)
  _$$StudentProfileImplCopyWith<_$StudentProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
