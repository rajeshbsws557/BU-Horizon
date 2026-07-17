// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BusRouteImpl _$$BusRouteImplFromJson(Map<String, dynamic> json) =>
    _$BusRouteImpl(
      name: json['name'] as String,
      window: json['window'] as String,
      frequency: json['frequency'] as String,
      nextBus: json['nextBus'] as String,
      favorite: json['favorite'] as bool? ?? false,
    );

Map<String, dynamic> _$$BusRouteImplToJson(_$BusRouteImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'window': instance.window,
      'frequency': instance.frequency,
      'nextBus': instance.nextBus,
      'favorite': instance.favorite,
    };
