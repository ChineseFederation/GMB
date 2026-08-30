// This is a generated file - do not edit.
//
// Generated from chat_envelope.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'chat_envelope.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'chat_envelope.pbenum.dart';

class ChatRoute extends $pb.GeneratedMessage {
  factory ChatRoute({
    $core.String? peerUserId,
    $core.String? routeDisplayName,
    $core.String? deviceId,
    $core.String? devicePublicKey,
    $core.String? safetyNumber,
    $core.String? nearbyPeerHint,
    $fixnum.Int64? createdAtMillis,
    $fixnum.Int64? expiresAtMillis,
  }) {
    final result = create();
    if (peerUserId != null) result.peerUserId = peerUserId;
    if (routeDisplayName != null) result.routeDisplayName = routeDisplayName;
    if (deviceId != null) result.deviceId = deviceId;
    if (devicePublicKey != null) result.devicePublicKey = devicePublicKey;
    if (safetyNumber != null) result.safetyNumber = safetyNumber;
    if (nearbyPeerHint != null) result.nearbyPeerHint = nearbyPeerHint;
    if (createdAtMillis != null) result.createdAtMillis = createdAtMillis;
    if (expiresAtMillis != null) result.expiresAtMillis = expiresAtMillis;
    return result;
  }

  ChatRoute._();

  factory ChatRoute.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatRoute.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatRoute',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gmb.chat'),
      createEmptyInstance: create)
    ..aOS(2, _omitFieldNames ? '' : 'peerUserId')
    ..aOS(3, _omitFieldNames ? '' : 'routeDisplayName')
    ..aOS(4, _omitFieldNames ? '' : 'deviceId')
    ..aOS(5, _omitFieldNames ? '' : 'devicePublicKey')
    ..aOS(6, _omitFieldNames ? '' : 'safetyNumber')
    ..aOS(7, _omitFieldNames ? '' : 'nearbyPeerHint')
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'createdAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'expiresAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRoute clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatRoute copyWith(void Function(ChatRoute) updates) =>
      super.copyWith((message) => updates(message as ChatRoute)) as ChatRoute;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatRoute create() => ChatRoute._();
  @$core.override
  ChatRoute createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatRoute getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatRoute>(create);
  static ChatRoute? _defaultInstance;

  @$pb.TagNumber(2)
  $core.String get peerUserId => $_getSZ(0);
  @$pb.TagNumber(2)
  set peerUserId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerUserId() => $_has(0);
  @$pb.TagNumber(2)
  void clearPeerUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get routeDisplayName => $_getSZ(1);
  @$pb.TagNumber(3)
  set routeDisplayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasRouteDisplayName() => $_has(1);
  @$pb.TagNumber(3)
  void clearRouteDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceId => $_getSZ(2);
  @$pb.TagNumber(4)
  set deviceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceId() => $_has(2);
  @$pb.TagNumber(4)
  void clearDeviceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get devicePublicKey => $_getSZ(3);
  @$pb.TagNumber(5)
  set devicePublicKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasDevicePublicKey() => $_has(3);
  @$pb.TagNumber(5)
  void clearDevicePublicKey() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get safetyNumber => $_getSZ(4);
  @$pb.TagNumber(6)
  set safetyNumber($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasSafetyNumber() => $_has(4);
  @$pb.TagNumber(6)
  void clearSafetyNumber() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get nearbyPeerHint => $_getSZ(5);
  @$pb.TagNumber(7)
  set nearbyPeerHint($core.String value) => $_setString(5, value);
  @$pb.TagNumber(7)
  $core.bool hasNearbyPeerHint() => $_has(5);
  @$pb.TagNumber(7)
  void clearNearbyPeerHint() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdAtMillis => $_getI64(6);
  @$pb.TagNumber(8)
  set createdAtMillis($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAtMillis() => $_has(6);
  @$pb.TagNumber(8)
  void clearCreatedAtMillis() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get expiresAtMillis => $_getI64(7);
  @$pb.TagNumber(9)
  set expiresAtMillis($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(9)
  $core.bool hasExpiresAtMillis() => $_has(7);
  @$pb.TagNumber(9)
  void clearExpiresAtMillis() => $_clearField(9);
}

class ChatEnvelope extends $pb.GeneratedMessage {
  factory ChatEnvelope({
    $core.String? envelopeId,
    $core.String? conversationId,
    $core.String? senderUserId,
    $core.String? recipientUserId,
    $core.String? senderDeviceId,
    $core.List<$core.int>? mlsMessage,
    $core.List<$core.int>? encryptedMetadata,
    $fixnum.Int64? createdAtMillis,
    $fixnum.Int64? ttlMillis,
    MlsWireMessageKind? mlsMessageKind,
    $core.List<$core.int>? ratchetTree,
  }) {
    final result = create();
    if (envelopeId != null) result.envelopeId = envelopeId;
    if (conversationId != null) result.conversationId = conversationId;
    if (senderUserId != null) result.senderUserId = senderUserId;
    if (recipientUserId != null) result.recipientUserId = recipientUserId;
    if (senderDeviceId != null) result.senderDeviceId = senderDeviceId;
    if (mlsMessage != null) result.mlsMessage = mlsMessage;
    if (encryptedMetadata != null) result.encryptedMetadata = encryptedMetadata;
    if (createdAtMillis != null) result.createdAtMillis = createdAtMillis;
    if (ttlMillis != null) result.ttlMillis = ttlMillis;
    if (mlsMessageKind != null) result.mlsMessageKind = mlsMessageKind;
    if (ratchetTree != null) result.ratchetTree = ratchetTree;
    return result;
  }

  ChatEnvelope._();

  factory ChatEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'gmb.chat'),
      createEmptyInstance: create)
    ..aOS(2, _omitFieldNames ? '' : 'envelopeId')
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..aOS(4, _omitFieldNames ? '' : 'senderUserId')
    ..aOS(5, _omitFieldNames ? '' : 'recipientUserId')
    ..aOS(6, _omitFieldNames ? '' : 'senderDeviceId')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'mlsMessage', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'encryptedMetadata', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(
        9, _omitFieldNames ? '' : 'createdAtMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        10, _omitFieldNames ? '' : 'ttlMillis', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<MlsWireMessageKind>(11, _omitFieldNames ? '' : 'mlsMessageKind',
        enumValues: MlsWireMessageKind.values)
    ..a<$core.List<$core.int>>(
        12, _omitFieldNames ? '' : 'ratchetTree', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatEnvelope copyWith(void Function(ChatEnvelope) updates) =>
      super.copyWith((message) => updates(message as ChatEnvelope))
          as ChatEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatEnvelope create() => ChatEnvelope._();
  @$core.override
  ChatEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatEnvelope>(create);
  static ChatEnvelope? _defaultInstance;

  @$pb.TagNumber(2)
  $core.String get envelopeId => $_getSZ(0);
  @$pb.TagNumber(2)
  set envelopeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasEnvelopeId() => $_has(0);
  @$pb.TagNumber(2)
  void clearEnvelopeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderUserId => $_getSZ(2);
  @$pb.TagNumber(4)
  set senderUserId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderUserId() => $_has(2);
  @$pb.TagNumber(4)
  void clearSenderUserId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get recipientUserId => $_getSZ(3);
  @$pb.TagNumber(5)
  set recipientUserId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasRecipientUserId() => $_has(3);
  @$pb.TagNumber(5)
  void clearRecipientUserId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get senderDeviceId => $_getSZ(4);
  @$pb.TagNumber(6)
  set senderDeviceId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderDeviceId() => $_has(4);
  @$pb.TagNumber(6)
  void clearSenderDeviceId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get mlsMessage => $_getN(5);
  @$pb.TagNumber(7)
  set mlsMessage($core.List<$core.int> value) => $_setBytes(5, value);
  @$pb.TagNumber(7)
  $core.bool hasMlsMessage() => $_has(5);
  @$pb.TagNumber(7)
  void clearMlsMessage() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get encryptedMetadata => $_getN(6);
  @$pb.TagNumber(8)
  set encryptedMetadata($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(8)
  $core.bool hasEncryptedMetadata() => $_has(6);
  @$pb.TagNumber(8)
  void clearEncryptedMetadata() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get createdAtMillis => $_getI64(7);
  @$pb.TagNumber(9)
  set createdAtMillis($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAtMillis() => $_has(7);
  @$pb.TagNumber(9)
  void clearCreatedAtMillis() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get ttlMillis => $_getI64(8);
  @$pb.TagNumber(10)
  set ttlMillis($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(10)
  $core.bool hasTtlMillis() => $_has(8);
  @$pb.TagNumber(10)
  void clearTtlMillis() => $_clearField(10);

  @$pb.TagNumber(11)
  MlsWireMessageKind get mlsMessageKind => $_getN(9);
  @$pb.TagNumber(11)
  set mlsMessageKind(MlsWireMessageKind value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasMlsMessageKind() => $_has(9);
  @$pb.TagNumber(11)
  void clearMlsMessageKind() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.List<$core.int> get ratchetTree => $_getN(10);
  @$pb.TagNumber(12)
  set ratchetTree($core.List<$core.int> value) => $_setBytes(10, value);
  @$pb.TagNumber(12)
  $core.bool hasRatchetTree() => $_has(10);
  @$pb.TagNumber(12)
  void clearRatchetTree() => $_clearField(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
