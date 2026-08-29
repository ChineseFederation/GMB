// This is a generated file - do not edit.
//
// Generated from chat_envelope.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use mlsWireMessageKindDescriptor instead')
const MlsWireMessageKind$json = {
  '1': 'MlsWireMessageKind',
  '2': [
    {'1': 'MLS_WIRE_MESSAGE_KIND_UNSPECIFIED', '2': 0},
    {'1': 'MLS_WIRE_MESSAGE_KIND_WELCOME', '2': 1},
    {'1': 'MLS_WIRE_MESSAGE_KIND_APPLICATION', '2': 2},
  ],
};

/// Descriptor for `MlsWireMessageKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List mlsWireMessageKindDescriptor = $convert.base64Decode(
    'ChJNbHNXaXJlTWVzc2FnZUtpbmQSJQohTUxTX1dJUkVfTUVTU0FHRV9LSU5EX1VOU1BFQ0lGSU'
    'VEEAASIQodTUxTX1dJUkVfTUVTU0FHRV9LSU5EX1dFTENPTUUQARIlCiFNTFNfV0lSRV9NRVNT'
    'QUdFX0tJTkRfQVBQTElDQVRJT04QAg==');

@$core.Deprecated('Use chatRouteDescriptor instead')
const ChatRoute$json = {
  '1': 'ChatRoute',
  '2': [
    {'1': 'peer_cid_number', '3': 2, '4': 1, '5': 9, '10': 'peerCidNumber'},
    {
      '1': 'route_display_name',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'routeDisplayName'
    },
    {'1': 'device_id', '3': 4, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'device_public_key', '3': 5, '4': 1, '5': 9, '10': 'devicePublicKey'},
    {'1': 'safety_number', '3': 6, '4': 1, '5': 9, '10': 'safetyNumber'},
    {'1': 'nearby_peer_hint', '3': 7, '4': 1, '5': 9, '10': 'nearbyPeerHint'},
    {'1': 'created_at_millis', '3': 8, '4': 1, '5': 4, '10': 'createdAtMillis'},
    {'1': 'expires_at_millis', '3': 9, '4': 1, '5': 4, '10': 'expiresAtMillis'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `ChatRoute`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatRouteDescriptor = $convert.base64Decode(
    'CglDaGF0Um91dGUSJgoPcGVlcl9jaWRfbnVtYmVyGAIgASgJUg1wZWVyQ2lkTnVtYmVyEiwKEn'
    'JvdXRlX2Rpc3BsYXlfbmFtZRgDIAEoCVIQcm91dGVEaXNwbGF5TmFtZRIbCglkZXZpY2VfaWQY'
    'BCABKAlSCGRldmljZUlkEioKEWRldmljZV9wdWJsaWNfa2V5GAUgASgJUg9kZXZpY2VQdWJsaW'
    'NLZXkSIwoNc2FmZXR5X251bWJlchgGIAEoCVIMc2FmZXR5TnVtYmVyEigKEG5lYXJieV9wZWVy'
    'X2hpbnQYByABKAlSDm5lYXJieVBlZXJIaW50EioKEWNyZWF0ZWRfYXRfbWlsbGlzGAggASgEUg'
    '9jcmVhdGVkQXRNaWxsaXMSKgoRZXhwaXJlc19hdF9taWxsaXMYCSABKARSD2V4cGlyZXNBdE1p'
    'bGxpc0oECAEQAg==');

@$core.Deprecated('Use chatEnvelopeDescriptor instead')
const ChatEnvelope$json = {
  '1': 'ChatEnvelope',
  '2': [
    {'1': 'envelope_id', '3': 2, '4': 1, '5': 9, '10': 'envelopeId'},
    {'1': 'conversation_id', '3': 3, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'sender_cid_number', '3': 4, '4': 1, '5': 9, '10': 'senderCidNumber'},
    {
      '1': 'recipient_cid_number',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'recipientCidNumber'
    },
    {'1': 'sender_device_id', '3': 6, '4': 1, '5': 9, '10': 'senderDeviceId'},
    {'1': 'mls_wire_message', '3': 7, '4': 1, '5': 12, '10': 'mlsWireMessage'},
    {
      '1': 'encrypted_metadata',
      '3': 8,
      '4': 1,
      '5': 12,
      '10': 'encryptedMetadata'
    },
    {'1': 'created_at_millis', '3': 9, '4': 1, '5': 4, '10': 'createdAtMillis'},
    {'1': 'ttl_millis', '3': 10, '4': 1, '5': 4, '10': 'ttlMillis'},
    {
      '1': 'mls_message_kind',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.gmb.chat.MlsWireMessageKind',
      '10': 'mlsMessageKind'
    },
    {'1': 'ratchet_tree', '3': 12, '4': 1, '5': 12, '10': 'ratchetTree'},
  ],
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `ChatEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatEnvelopeDescriptor = $convert.base64Decode(
    'CgxDaGF0RW52ZWxvcGUSHwoLZW52ZWxvcGVfaWQYAiABKAlSCmVudmVsb3BlSWQSJwoPY29udm'
    'Vyc2F0aW9uX2lkGAMgASgJUg5jb252ZXJzYXRpb25JZBIqChFzZW5kZXJfY2lkX251bWJlchgE'
    'IAEoCVIPc2VuZGVyQ2lkTnVtYmVyEjAKFHJlY2lwaWVudF9jaWRfbnVtYmVyGAUgASgJUhJyZW'
    'NpcGllbnRDaWROdW1iZXISKAoQc2VuZGVyX2RldmljZV9pZBgGIAEoCVIOc2VuZGVyRGV2aWNl'
    'SWQSKAoQbWxzX3dpcmVfbWVzc2FnZRgHIAEoDFIObWxzV2lyZU1lc3NhZ2USLQoSZW5jcnlwdG'
    'VkX21ldGFkYXRhGAggASgMUhFlbmNyeXB0ZWRNZXRhZGF0YRIqChFjcmVhdGVkX2F0X21pbGxp'
    'cxgJIAEoBFIPY3JlYXRlZEF0TWlsbGlzEh0KCnR0bF9taWxsaXMYCiABKARSCXR0bE1pbGxpcx'
    'JGChBtbHNfbWVzc2FnZV9raW5kGAsgASgOMhwuZ21iLmNoYXQuTWxzV2lyZU1lc3NhZ2VLaW5k'
    'Ug5tbHNNZXNzYWdlS2luZBIhCgxyYXRjaGV0X3RyZWUYDCABKAxSC3JhdGNoZXRUcmVlSgQIAR'
    'AC');
