// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatConversationEntityCollection on Isar {
  IsarCollection<ChatConversationEntity> get chatConversationEntitys =>
      this.collection();
}

const ChatConversationEntitySchema = CollectionSchema(
  name: r'ChatConversationEntity',
  id: 6241151859022060416,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'bindingRevision': PropertySchema(
      id: 1,
      name: r'bindingRevision',
      type: IsarType.long,
    ),
    r'conversationId': PropertySchema(
      id: 2,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'conversationKind': PropertySchema(
      id: 3,
      name: r'conversationKind',
      type: IsarType.string,
    ),
    r'lastDeliveryState': PropertySchema(
      id: 4,
      name: r'lastDeliveryState',
      type: IsarType.string,
    ),
    r'lastMessageCipher': PropertySchema(
      id: 5,
      name: r'lastMessageCipher',
      type: IsarType.string,
    ),
    r'lastUpdatedAtMillis': PropertySchema(
      id: 6,
      name: r'lastUpdatedAtMillis',
      type: IsarType.long,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 7,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'peerCidNumber': PropertySchema(
      id: 8,
      name: r'peerCidNumber',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 9,
      name: r'title',
      type: IsarType.string,
    ),
    r'unreadCount': PropertySchema(
      id: 10,
      name: r'unreadCount',
      type: IsarType.long,
    )
  },
  estimateSize: _chatConversationEntityEstimateSize,
  serialize: _chatConversationEntitySerialize,
  deserialize: _chatConversationEntityDeserialize,
  deserializeProp: _chatConversationEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_conversationId': IndexSchema(
      id: -7424835351205823844,
      name: r'ownerCidNumber_conversationId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'peerCidNumber': IndexSchema(
      id: 8594361946077179915,
      name: r'peerCidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'peerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'lastUpdatedAtMillis': IndexSchema(
      id: 6170169168052042175,
      name: r'lastUpdatedAtMillis',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastUpdatedAtMillis',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatConversationEntityGetId,
  getLinks: _chatConversationEntityGetLinks,
  attach: _chatConversationEntityAttach,
  version: '3.3.2',
);

int _chatConversationEntityEstimateSize(
  ChatConversationEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  {
    final value = object.conversationKind;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.lastDeliveryState.length * 3;
  bytesCount += 3 + object.lastMessageCipher.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.peerCidNumber.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _chatConversationEntitySerialize(
  ChatConversationEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeString(offsets[2], object.conversationId);
  writer.writeString(offsets[3], object.conversationKind);
  writer.writeString(offsets[4], object.lastDeliveryState);
  writer.writeString(offsets[5], object.lastMessageCipher);
  writer.writeLong(offsets[6], object.lastUpdatedAtMillis);
  writer.writeString(offsets[7], object.ownerCidNumber);
  writer.writeString(offsets[8], object.peerCidNumber);
  writer.writeString(offsets[9], object.title);
  writer.writeLong(offsets[10], object.unreadCount);
}

ChatConversationEntity _chatConversationEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatConversationEntity();
  object.accountId = reader.readString(offsets[0]);
  object.bindingRevision = reader.readLong(offsets[1]);
  object.conversationId = reader.readString(offsets[2]);
  object.conversationKind = reader.readStringOrNull(offsets[3]);
  object.id = id;
  object.lastDeliveryState = reader.readString(offsets[4]);
  object.lastMessageCipher = reader.readString(offsets[5]);
  object.lastUpdatedAtMillis = reader.readLong(offsets[6]);
  object.ownerCidNumber = reader.readString(offsets[7]);
  object.peerCidNumber = reader.readString(offsets[8]);
  object.title = reader.readString(offsets[9]);
  object.unreadCount = reader.readLong(offsets[10]);
  return object;
}

P _chatConversationEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatConversationEntityGetId(ChatConversationEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatConversationEntityGetLinks(
    ChatConversationEntity object) {
  return [];
}

void _chatConversationEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatConversationEntity object) {
  object.id = id;
}

extension ChatConversationEntityByIndex
    on IsarCollection<ChatConversationEntity> {
  Future<ChatConversationEntity?> getByOwnerCidNumberConversationId(
      String ownerCidNumber, String conversationId) {
    return getByIndex(
        r'ownerCidNumber_conversationId', [ownerCidNumber, conversationId]);
  }

  ChatConversationEntity? getByOwnerCidNumberConversationIdSync(
      String ownerCidNumber, String conversationId) {
    return getByIndexSync(
        r'ownerCidNumber_conversationId', [ownerCidNumber, conversationId]);
  }

  Future<bool> deleteByOwnerCidNumberConversationId(
      String ownerCidNumber, String conversationId) {
    return deleteByIndex(
        r'ownerCidNumber_conversationId', [ownerCidNumber, conversationId]);
  }

  bool deleteByOwnerCidNumberConversationIdSync(
      String ownerCidNumber, String conversationId) {
    return deleteByIndexSync(
        r'ownerCidNumber_conversationId', [ownerCidNumber, conversationId]);
  }

  Future<List<ChatConversationEntity?>> getAllByOwnerCidNumberConversationId(
      List<String> ownerCidNumberValues, List<String> conversationIdValues) {
    final len = ownerCidNumberValues.length;
    assert(conversationIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], conversationIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_conversationId', values);
  }

  List<ChatConversationEntity?> getAllByOwnerCidNumberConversationIdSync(
      List<String> ownerCidNumberValues, List<String> conversationIdValues) {
    final len = ownerCidNumberValues.length;
    assert(conversationIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], conversationIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_conversationId', values);
  }

  Future<int> deleteAllByOwnerCidNumberConversationId(
      List<String> ownerCidNumberValues, List<String> conversationIdValues) {
    final len = ownerCidNumberValues.length;
    assert(conversationIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], conversationIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_conversationId', values);
  }

  int deleteAllByOwnerCidNumberConversationIdSync(
      List<String> ownerCidNumberValues, List<String> conversationIdValues) {
    final len = ownerCidNumberValues.length;
    assert(conversationIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], conversationIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_conversationId', values);
  }

  Future<Id> putByOwnerCidNumberConversationId(ChatConversationEntity object) {
    return putByIndex(r'ownerCidNumber_conversationId', object);
  }

  Id putByOwnerCidNumberConversationIdSync(ChatConversationEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_conversationId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberConversationId(
      List<ChatConversationEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_conversationId', objects);
  }

  List<Id> putAllByOwnerCidNumberConversationIdSync(
      List<ChatConversationEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_conversationId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatConversationEntityQueryWhereSort
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QWhere> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterWhere>
      anyLastUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastUpdatedAtMillis'),
      );
    });
  }
}

extension ChatConversationEntityQueryWhere on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QWhereClause> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToAnyConversationId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_conversationId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterWhereClause>
      ownerCidNumberNotEqualToAnyConversationId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterWhereClause>
      ownerCidNumberConversationIdEqualTo(
          String ownerCidNumber, String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_conversationId',
        value: [ownerCidNumber, conversationId],
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToConversationIdNotEqualTo(
          String ownerCidNumber, String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber, conversationId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber, conversationId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_conversationId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, conversationId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> peerCidNumberEqualTo(String peerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'peerCidNumber',
        value: [peerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> peerCidNumberNotEqualTo(String peerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerCidNumber',
              lower: [],
              upper: [peerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerCidNumber',
              lower: [peerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerCidNumber',
              lower: [peerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerCidNumber',
              lower: [],
              upper: [peerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> lastUpdatedAtMillisEqualTo(int lastUpdatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lastUpdatedAtMillis',
        value: [lastUpdatedAtMillis],
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterWhereClause>
      lastUpdatedAtMillisNotEqualTo(int lastUpdatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastUpdatedAtMillis',
              lower: [],
              upper: [lastUpdatedAtMillis],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastUpdatedAtMillis',
              lower: [lastUpdatedAtMillis],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastUpdatedAtMillis',
              lower: [lastUpdatedAtMillis],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lastUpdatedAtMillis',
              lower: [],
              upper: [lastUpdatedAtMillis],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> lastUpdatedAtMillisGreaterThan(
    int lastUpdatedAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastUpdatedAtMillis',
        lower: [lastUpdatedAtMillis],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> lastUpdatedAtMillisLessThan(
    int lastUpdatedAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastUpdatedAtMillis',
        lower: [],
        upper: [lastUpdatedAtMillis],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterWhereClause> lastUpdatedAtMillisBetween(
    int lowerLastUpdatedAtMillis,
    int upperLastUpdatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'lastUpdatedAtMillis',
        lower: [lowerLastUpdatedAtMillis],
        includeLower: includeLower,
        upper: [upperLastUpdatedAtMillis],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatConversationEntityQueryFilter on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QFilterCondition> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'accountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> bindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> bindingRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> bindingRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> bindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'conversationKind',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'conversationKind',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      conversationKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      conversationKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationKind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> conversationKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastDeliveryState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      lastDeliveryStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastDeliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      lastDeliveryStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastDeliveryState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastDeliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastDeliveryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastDeliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastMessageCipher',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      lastMessageCipherContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastMessageCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      lastMessageCipherMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastMessageCipher',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastMessageCipher',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastMessageCipherIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastMessageCipher',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastUpdatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastUpdatedAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastUpdatedAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> lastUpdatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdatedAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'peerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      peerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      peerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'peerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> peerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'peerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
          QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> unreadCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> unreadCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> unreadCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'unreadCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity,
      QAfterFilterCondition> unreadCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'unreadCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatConversationEntityQueryObject on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QFilterCondition> {}

extension ChatConversationEntityQueryLinks on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QFilterCondition> {}

extension ChatConversationEntityQuerySortBy
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QSortBy> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByConversationKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationKind', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByConversationKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationKind', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDeliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDeliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastMessageCipher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageCipher', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastMessageCipherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageCipher', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByLastUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByPeerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByPeerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      sortByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }
}

extension ChatConversationEntityQuerySortThenBy on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QSortThenBy> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByConversationKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationKind', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByConversationKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationKind', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDeliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDeliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastMessageCipher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageCipher', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastMessageCipherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastMessageCipher', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByLastUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdatedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByPeerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByPeerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
      thenByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadCount', Sort.desc);
    });
  }
}

extension ChatConversationEntityQueryWhereDistinct
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bindingRevision');
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByConversationKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationKind',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByLastDeliveryState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastDeliveryState',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByLastMessageCipher({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastMessageCipher',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByLastUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdatedAtMillis');
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByPeerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
      distinctByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unreadCount');
    });
  }
}

extension ChatConversationEntityQueryProperty on QueryBuilder<
    ChatConversationEntity, ChatConversationEntity, QQueryProperty> {
  QueryBuilder<ChatConversationEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
      bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bindingRevision');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<ChatConversationEntity, String?, QQueryOperations>
      conversationKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationKind');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      lastDeliveryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastDeliveryState');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      lastMessageCipherProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastMessageCipher');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
      lastUpdatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdatedAtMillis');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      peerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peerCidNumber');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
      titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
      unreadCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unreadCount');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatMessageEntityCollection on Isar {
  IsarCollection<ChatMessageEntity> get chatMessageEntitys => this.collection();
}

const ChatMessageEntitySchema = CollectionSchema(
  name: r'ChatMessageEntity',
  id: 8398983736130033389,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'bindingRevision': PropertySchema(
      id: 1,
      name: r'bindingRevision',
      type: IsarType.long,
    ),
    r'conversationId': PropertySchema(
      id: 2,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'createdAtMillis': PropertySchema(
      id: 3,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'deliveryState': PropertySchema(
      id: 4,
      name: r'deliveryState',
      type: IsarType.string,
    ),
    r'direction': PropertySchema(
      id: 5,
      name: r'direction',
      type: IsarType.string,
    ),
    r'envelopeBytesHex': PropertySchema(
      id: 6,
      name: r'envelopeBytesHex',
      type: IsarType.string,
    ),
    r'envelopeId': PropertySchema(
      id: 7,
      name: r'envelopeId',
      type: IsarType.string,
    ),
    r'messageKind': PropertySchema(
      id: 8,
      name: r'messageKind',
      type: IsarType.string,
    ),
    r'mlsMessageKind': PropertySchema(
      id: 9,
      name: r'mlsMessageKind',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 10,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'plaintextCipher': PropertySchema(
      id: 11,
      name: r'plaintextCipher',
      type: IsarType.string,
    ),
    r'recipientCidNumber': PropertySchema(
      id: 12,
      name: r'recipientCidNumber',
      type: IsarType.string,
    ),
    r'searchTokens': PropertySchema(
      id: 13,
      name: r'searchTokens',
      type: IsarType.stringList,
    ),
    r'senderCidNumber': PropertySchema(
      id: 14,
      name: r'senderCidNumber',
      type: IsarType.string,
    ),
    r'senderDeviceId': PropertySchema(
      id: 15,
      name: r'senderDeviceId',
      type: IsarType.string,
    )
  },
  estimateSize: _chatMessageEntityEstimateSize,
  serialize: _chatMessageEntitySerialize,
  deserialize: _chatMessageEntityDeserialize,
  deserializeProp: _chatMessageEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_envelopeId': IndexSchema(
      id: 3891964785492803984,
      name: r'ownerCidNumber_envelopeId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'envelopeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'searchTokens': IndexSchema(
      id: 2062148741461982474,
      name: r'searchTokens',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'searchTokens',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAtMillis': IndexSchema(
      id: -2739706252225730577,
      name: r'createdAtMillis',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAtMillis',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatMessageEntityGetId,
  getLinks: _chatMessageEntityGetLinks,
  attach: _chatMessageEntityAttach,
  version: '3.3.2',
);

int _chatMessageEntityEstimateSize(
  ChatMessageEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.deliveryState.length * 3;
  bytesCount += 3 + object.direction.length * 3;
  bytesCount += 3 + object.envelopeBytesHex.length * 3;
  bytesCount += 3 + object.envelopeId.length * 3;
  bytesCount += 3 + object.messageKind.length * 3;
  bytesCount += 3 + object.mlsMessageKind.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  {
    final value = object.plaintextCipher;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.recipientCidNumber.length * 3;
  bytesCount += 3 + object.searchTokens.length * 3;
  {
    for (var i = 0; i < object.searchTokens.length; i++) {
      final value = object.searchTokens[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.senderCidNumber.length * 3;
  bytesCount += 3 + object.senderDeviceId.length * 3;
  return bytesCount;
}

void _chatMessageEntitySerialize(
  ChatMessageEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeString(offsets[2], object.conversationId);
  writer.writeLong(offsets[3], object.createdAtMillis);
  writer.writeString(offsets[4], object.deliveryState);
  writer.writeString(offsets[5], object.direction);
  writer.writeString(offsets[6], object.envelopeBytesHex);
  writer.writeString(offsets[7], object.envelopeId);
  writer.writeString(offsets[8], object.messageKind);
  writer.writeString(offsets[9], object.mlsMessageKind);
  writer.writeString(offsets[10], object.ownerCidNumber);
  writer.writeString(offsets[11], object.plaintextCipher);
  writer.writeString(offsets[12], object.recipientCidNumber);
  writer.writeStringList(offsets[13], object.searchTokens);
  writer.writeString(offsets[14], object.senderCidNumber);
  writer.writeString(offsets[15], object.senderDeviceId);
}

ChatMessageEntity _chatMessageEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatMessageEntity();
  object.accountId = reader.readString(offsets[0]);
  object.bindingRevision = reader.readLong(offsets[1]);
  object.conversationId = reader.readString(offsets[2]);
  object.createdAtMillis = reader.readLong(offsets[3]);
  object.deliveryState = reader.readString(offsets[4]);
  object.direction = reader.readString(offsets[5]);
  object.envelopeBytesHex = reader.readString(offsets[6]);
  object.envelopeId = reader.readString(offsets[7]);
  object.id = id;
  object.messageKind = reader.readString(offsets[8]);
  object.mlsMessageKind = reader.readString(offsets[9]);
  object.ownerCidNumber = reader.readString(offsets[10]);
  object.plaintextCipher = reader.readStringOrNull(offsets[11]);
  object.recipientCidNumber = reader.readString(offsets[12]);
  object.searchTokens = reader.readStringList(offsets[13]) ?? [];
  object.senderCidNumber = reader.readString(offsets[14]);
  object.senderDeviceId = reader.readString(offsets[15]);
  return object;
}

P _chatMessageEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringList(offset) ?? []) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatMessageEntityGetId(ChatMessageEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatMessageEntityGetLinks(
    ChatMessageEntity object) {
  return [];
}

void _chatMessageEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatMessageEntity object) {
  object.id = id;
}

extension ChatMessageEntityByIndex on IsarCollection<ChatMessageEntity> {
  Future<ChatMessageEntity?> getByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return getByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  ChatMessageEntity? getByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return getByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<bool> deleteByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  bool deleteByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<List<ChatMessageEntity?>> getAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  List<ChatMessageEntity?> getAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<int> deleteAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  int deleteAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<Id> putByOwnerCidNumberEnvelopeId(ChatMessageEntity object) {
    return putByIndex(r'ownerCidNumber_envelopeId', object);
  }

  Id putByOwnerCidNumberEnvelopeIdSync(ChatMessageEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_envelopeId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberEnvelopeId(
      List<ChatMessageEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_envelopeId', objects);
  }

  List<Id> putAllByOwnerCidNumberEnvelopeIdSync(List<ChatMessageEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_envelopeId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatMessageEntityQueryWhereSort
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QWhere> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere>
      anySearchTokensElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'searchTokens'),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere>
      anyCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAtMillis'),
      );
    });
  }
}

extension ChatMessageEntityQueryWhere
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QWhereClause> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      ownerCidNumberEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      ownerCidNumberNotEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      ownerCidNumberEnvelopeIdEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber, envelopeId],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      ownerCidNumberEqualToEnvelopeIdNotEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conversationId',
        value: [conversationId],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementEqualTo(String searchTokensElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'searchTokens',
        value: [searchTokensElement],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementNotEqualTo(String searchTokensElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'searchTokens',
              lower: [],
              upper: [searchTokensElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'searchTokens',
              lower: [searchTokensElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'searchTokens',
              lower: [searchTokensElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'searchTokens',
              lower: [],
              upper: [searchTokensElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementGreaterThan(
    String searchTokensElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'searchTokens',
        lower: [searchTokensElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementLessThan(
    String searchTokensElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'searchTokens',
        lower: [],
        upper: [searchTokensElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementBetween(
    String lowerSearchTokensElement,
    String upperSearchTokensElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'searchTokens',
        lower: [lowerSearchTokensElement],
        includeLower: includeLower,
        upper: [upperSearchTokensElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementStartsWith(String SearchTokensElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'searchTokens',
        lower: [SearchTokensElementPrefix],
        upper: ['$SearchTokensElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'searchTokens',
        value: [''],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      searchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'searchTokens',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'searchTokens',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'searchTokens',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'searchTokens',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      createdAtMillisEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAtMillis',
        value: [createdAtMillis],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      createdAtMillisNotEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [],
              upper: [createdAtMillis],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [createdAtMillis],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [createdAtMillis],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [],
              upper: [createdAtMillis],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      createdAtMillisGreaterThan(
    int createdAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [createdAtMillis],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      createdAtMillisLessThan(
    int createdAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [],
        upper: [createdAtMillis],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
      createdAtMillisBetween(
    int lowerCreatedAtMillis,
    int upperCreatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [lowerCreatedAtMillis],
        includeLower: includeLower,
        upper: [upperCreatedAtMillis],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatMessageEntityQueryFilter
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'accountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      bindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      bindingRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      bindingRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      bindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deliveryState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deliveryState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      deliveryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'direction',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'direction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'direction',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'direction',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      directionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'direction',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeBytesHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeBytesHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      envelopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageKind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mlsMessageKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mlsMessageKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mlsMessageKind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mlsMessageKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      mlsMessageKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mlsMessageKind',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'plaintextCipher',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'plaintextCipher',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'plaintextCipher',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'plaintextCipher',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'plaintextCipher',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'plaintextCipher',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      plaintextCipherIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'plaintextCipher',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipientCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipientCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'searchTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'searchTokens',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'searchTokens',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'searchTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'searchTokens',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      searchTokensLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'searchTokens',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'senderCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'senderCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'senderCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'senderCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'senderDeviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'senderDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'senderDeviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderDeviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'senderDeviceId',
        value: '',
      ));
    });
  }
}

extension ChatMessageEntityQueryObject
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {}

extension ChatMessageEntityQueryLinks
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {}

extension ChatMessageEntityQuerySortBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByDirection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByDirectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageKind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageKind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMlsMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mlsMessageKind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMlsMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mlsMessageKind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByPlaintextCipher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'plaintextCipher', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByPlaintextCipherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'plaintextCipher', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderDeviceId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderDeviceId', Sort.desc);
    });
  }
}

extension ChatMessageEntityQuerySortThenBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortThenBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByDirection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByDirectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageKind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageKind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMlsMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mlsMessageKind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMlsMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mlsMessageKind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByPlaintextCipher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'plaintextCipher', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByPlaintextCipherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'plaintextCipher', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderDeviceId', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderDeviceId', Sort.desc);
    });
  }
}

extension ChatMessageEntityQueryWhereDistinct
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bindingRevision');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByDeliveryState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deliveryState',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByDirection({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'direction', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByEnvelopeBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeBytesHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByEnvelopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByMessageKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageKind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByMlsMessageKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mlsMessageKind',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByPlaintextCipher({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'plaintextCipher',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctByRecipientCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipientCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctBySearchTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'searchTokens');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctBySenderCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
      distinctBySenderDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderDeviceId',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChatMessageEntityQueryProperty
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QQueryProperty> {
  QueryBuilder<ChatMessageEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<ChatMessageEntity, int, QQueryOperations>
      bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bindingRevision');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<ChatMessageEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      deliveryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryState');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      directionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'direction');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      envelopeBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeBytesHex');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      envelopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeId');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      messageKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageKind');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      mlsMessageKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mlsMessageKind');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatMessageEntity, String?, QQueryOperations>
      plaintextCipherProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'plaintextCipher');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      recipientCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipientCidNumber');
    });
  }

  QueryBuilder<ChatMessageEntity, List<String>, QQueryOperations>
      searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'searchTokens');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      senderCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderCidNumber');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
      senderDeviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderDeviceId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatOutboundQueueEntityCollection on Isar {
  IsarCollection<ChatOutboundQueueEntity> get chatOutboundQueueEntitys =>
      this.collection();
}

const ChatOutboundQueueEntitySchema = CollectionSchema(
  name: r'ChatOutboundQueueEntity',
  id: -4338550964144627327,
  properties: {
    r'attemptCount': PropertySchema(
      id: 0,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'conversationId': PropertySchema(
      id: 1,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'deliveryState': PropertySchema(
      id: 2,
      name: r'deliveryState',
      type: IsarType.string,
    ),
    r'envelopeBytesHex': PropertySchema(
      id: 3,
      name: r'envelopeBytesHex',
      type: IsarType.string,
    ),
    r'envelopeId': PropertySchema(
      id: 4,
      name: r'envelopeId',
      type: IsarType.string,
    ),
    r'lastError': PropertySchema(
      id: 5,
      name: r'lastError',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 6,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'recipientCidNumber': PropertySchema(
      id: 7,
      name: r'recipientCidNumber',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 8,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _chatOutboundQueueEntityEstimateSize,
  serialize: _chatOutboundQueueEntitySerialize,
  deserialize: _chatOutboundQueueEntityDeserialize,
  deserializeProp: _chatOutboundQueueEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_envelopeId': IndexSchema(
      id: 3891964785492803984,
      name: r'ownerCidNumber_envelopeId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'envelopeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'updatedAtMillis': IndexSchema(
      id: -5245432295617068179,
      name: r'updatedAtMillis',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAtMillis',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatOutboundQueueEntityGetId,
  getLinks: _chatOutboundQueueEntityGetLinks,
  attach: _chatOutboundQueueEntityAttach,
  version: '3.3.2',
);

int _chatOutboundQueueEntityEstimateSize(
  ChatOutboundQueueEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.deliveryState.length * 3;
  bytesCount += 3 + object.envelopeBytesHex.length * 3;
  bytesCount += 3 + object.envelopeId.length * 3;
  {
    final value = object.lastError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.recipientCidNumber.length * 3;
  return bytesCount;
}

void _chatOutboundQueueEntitySerialize(
  ChatOutboundQueueEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attemptCount);
  writer.writeString(offsets[1], object.conversationId);
  writer.writeString(offsets[2], object.deliveryState);
  writer.writeString(offsets[3], object.envelopeBytesHex);
  writer.writeString(offsets[4], object.envelopeId);
  writer.writeString(offsets[5], object.lastError);
  writer.writeString(offsets[6], object.ownerCidNumber);
  writer.writeString(offsets[7], object.recipientCidNumber);
  writer.writeLong(offsets[8], object.updatedAtMillis);
}

ChatOutboundQueueEntity _chatOutboundQueueEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatOutboundQueueEntity();
  object.attemptCount = reader.readLong(offsets[0]);
  object.conversationId = reader.readString(offsets[1]);
  object.deliveryState = reader.readString(offsets[2]);
  object.envelopeBytesHex = reader.readString(offsets[3]);
  object.envelopeId = reader.readString(offsets[4]);
  object.id = id;
  object.lastError = reader.readStringOrNull(offsets[5]);
  object.ownerCidNumber = reader.readString(offsets[6]);
  object.recipientCidNumber = reader.readString(offsets[7]);
  object.updatedAtMillis = reader.readLong(offsets[8]);
  return object;
}

P _chatOutboundQueueEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatOutboundQueueEntityGetId(ChatOutboundQueueEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatOutboundQueueEntityGetLinks(
    ChatOutboundQueueEntity object) {
  return [];
}

void _chatOutboundQueueEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatOutboundQueueEntity object) {
  object.id = id;
}

extension ChatOutboundQueueEntityByIndex
    on IsarCollection<ChatOutboundQueueEntity> {
  Future<ChatOutboundQueueEntity?> getByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return getByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  ChatOutboundQueueEntity? getByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return getByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<bool> deleteByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  bool deleteByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<List<ChatOutboundQueueEntity?>> getAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  List<ChatOutboundQueueEntity?> getAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<int> deleteAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  int deleteAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<Id> putByOwnerCidNumberEnvelopeId(ChatOutboundQueueEntity object) {
    return putByIndex(r'ownerCidNumber_envelopeId', object);
  }

  Id putByOwnerCidNumberEnvelopeIdSync(ChatOutboundQueueEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_envelopeId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberEnvelopeId(
      List<ChatOutboundQueueEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_envelopeId', objects);
  }

  List<Id> putAllByOwnerCidNumberEnvelopeIdSync(
      List<ChatOutboundQueueEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_envelopeId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatOutboundQueueEntityQueryWhereSort
    on QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QWhere> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterWhere>
      anyUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAtMillis'),
      );
    });
  }
}

extension ChatOutboundQueueEntityQueryWhere on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QWhereClause> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterWhereClause>
      ownerCidNumberNotEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterWhereClause>
      ownerCidNumberEnvelopeIdEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber, envelopeId],
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToEnvelopeIdNotEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conversationId',
        value: [conversationId],
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> updatedAtMillisEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAtMillis',
        value: [updatedAtMillis],
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> updatedAtMillisNotEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAtMillis',
              lower: [],
              upper: [updatedAtMillis],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAtMillis',
              lower: [updatedAtMillis],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAtMillis',
              lower: [updatedAtMillis],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAtMillis',
              lower: [],
              upper: [updatedAtMillis],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> updatedAtMillisGreaterThan(
    int updatedAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAtMillis',
        lower: [updatedAtMillis],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> updatedAtMillisLessThan(
    int updatedAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAtMillis',
        lower: [],
        upper: [updatedAtMillis],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterWhereClause> updatedAtMillisBetween(
    int lowerUpdatedAtMillis,
    int upperUpdatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAtMillis',
        lower: [lowerUpdatedAtMillis],
        includeLower: includeLower,
        upper: [upperUpdatedAtMillis],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatOutboundQueueEntityQueryFilter on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QFilterCondition> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> attemptCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> attemptCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> attemptCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deliveryState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      deliveryStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deliveryState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      deliveryStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deliveryState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> deliveryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deliveryState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeBytesHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      envelopeBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      envelopeBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeBytesHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      envelopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      envelopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> envelopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastError',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastError',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastError',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      lastErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      lastErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastError',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastError',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastError',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipientCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      recipientCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
          QAfterFilterCondition>
      recipientCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipientCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> recipientCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> updatedAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> updatedAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity,
      QAfterFilterCondition> updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatOutboundQueueEntityQueryObject on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QFilterCondition> {}

extension ChatOutboundQueueEntityQueryLinks on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QFilterCondition> {}

extension ChatOutboundQueueEntityQuerySortBy
    on QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QSortBy> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatOutboundQueueEntityQuerySortThenBy on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QSortThenBy> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryState', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatOutboundQueueEntityQueryWhereDistinct on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByDeliveryState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deliveryState',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByEnvelopeBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeBytesHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByEnvelopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByLastError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByRecipientCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipientCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension ChatOutboundQueueEntityQueryProperty on QueryBuilder<
    ChatOutboundQueueEntity, ChatOutboundQueueEntity, QQueryProperty> {
  QueryBuilder<ChatOutboundQueueEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, int, QQueryOperations>
      attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      deliveryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryState');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      envelopeBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeBytesHex');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      envelopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeId');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String?, QQueryOperations>
      lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastError');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
      recipientCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipientCidNumber');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatOutgoingMediaEntityCollection on Isar {
  IsarCollection<ChatOutgoingMediaEntity> get chatOutgoingMediaEntitys =>
      this.collection();
}

const ChatOutgoingMediaEntitySchema = CollectionSchema(
  name: r'ChatOutgoingMediaEntity',
  id: -2845887540690814187,
  properties: {
    r'attachmentId': PropertySchema(
      id: 0,
      name: r'attachmentId',
      type: IsarType.string,
    ),
    r'byteSize': PropertySchema(
      id: 1,
      name: r'byteSize',
      type: IsarType.long,
    ),
    r'contentType': PropertySchema(
      id: 2,
      name: r'contentType',
      type: IsarType.string,
    ),
    r'conversationId': PropertySchema(
      id: 3,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'createdAtMillis': PropertySchema(
      id: 4,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'fileName': PropertySchema(
      id: 5,
      name: r'fileName',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 6,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'pendingKey': PropertySchema(
      id: 7,
      name: r'pendingKey',
      type: IsarType.string,
    ),
    r'recipientCidNumber': PropertySchema(
      id: 8,
      name: r'recipientCidNumber',
      type: IsarType.string,
    )
  },
  estimateSize: _chatOutgoingMediaEntityEstimateSize,
  serialize: _chatOutgoingMediaEntitySerialize,
  deserialize: _chatOutgoingMediaEntityDeserialize,
  deserializeProp: _chatOutgoingMediaEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_pendingKey': IndexSchema(
      id: 1991019881256958296,
      name: r'ownerCidNumber_pendingKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'pendingKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'attachmentId': IndexSchema(
      id: 5677012331559006036,
      name: r'attachmentId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'attachmentId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'recipientCidNumber': IndexSchema(
      id: -230271759585326356,
      name: r'recipientCidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'recipientCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatOutgoingMediaEntityGetId,
  getLinks: _chatOutgoingMediaEntityGetLinks,
  attach: _chatOutgoingMediaEntityAttach,
  version: '3.3.2',
);

int _chatOutgoingMediaEntityEstimateSize(
  ChatOutgoingMediaEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attachmentId.length * 3;
  bytesCount += 3 + object.contentType.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.fileName.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.pendingKey.length * 3;
  bytesCount += 3 + object.recipientCidNumber.length * 3;
  return bytesCount;
}

void _chatOutgoingMediaEntitySerialize(
  ChatOutgoingMediaEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attachmentId);
  writer.writeLong(offsets[1], object.byteSize);
  writer.writeString(offsets[2], object.contentType);
  writer.writeString(offsets[3], object.conversationId);
  writer.writeLong(offsets[4], object.createdAtMillis);
  writer.writeString(offsets[5], object.fileName);
  writer.writeString(offsets[6], object.ownerCidNumber);
  writer.writeString(offsets[7], object.pendingKey);
  writer.writeString(offsets[8], object.recipientCidNumber);
}

ChatOutgoingMediaEntity _chatOutgoingMediaEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatOutgoingMediaEntity();
  object.attachmentId = reader.readString(offsets[0]);
  object.byteSize = reader.readLong(offsets[1]);
  object.contentType = reader.readString(offsets[2]);
  object.conversationId = reader.readString(offsets[3]);
  object.createdAtMillis = reader.readLong(offsets[4]);
  object.fileName = reader.readString(offsets[5]);
  object.id = id;
  object.ownerCidNumber = reader.readString(offsets[6]);
  object.pendingKey = reader.readString(offsets[7]);
  object.recipientCidNumber = reader.readString(offsets[8]);
  return object;
}

P _chatOutgoingMediaEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatOutgoingMediaEntityGetId(ChatOutgoingMediaEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatOutgoingMediaEntityGetLinks(
    ChatOutgoingMediaEntity object) {
  return [];
}

void _chatOutgoingMediaEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatOutgoingMediaEntity object) {
  object.id = id;
}

extension ChatOutgoingMediaEntityByIndex
    on IsarCollection<ChatOutgoingMediaEntity> {
  Future<ChatOutgoingMediaEntity?> getByOwnerCidNumberPendingKey(
      String ownerCidNumber, String pendingKey) {
    return getByIndex(
        r'ownerCidNumber_pendingKey', [ownerCidNumber, pendingKey]);
  }

  ChatOutgoingMediaEntity? getByOwnerCidNumberPendingKeySync(
      String ownerCidNumber, String pendingKey) {
    return getByIndexSync(
        r'ownerCidNumber_pendingKey', [ownerCidNumber, pendingKey]);
  }

  Future<bool> deleteByOwnerCidNumberPendingKey(
      String ownerCidNumber, String pendingKey) {
    return deleteByIndex(
        r'ownerCidNumber_pendingKey', [ownerCidNumber, pendingKey]);
  }

  bool deleteByOwnerCidNumberPendingKeySync(
      String ownerCidNumber, String pendingKey) {
    return deleteByIndexSync(
        r'ownerCidNumber_pendingKey', [ownerCidNumber, pendingKey]);
  }

  Future<List<ChatOutgoingMediaEntity?>> getAllByOwnerCidNumberPendingKey(
      List<String> ownerCidNumberValues, List<String> pendingKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(pendingKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], pendingKeyValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_pendingKey', values);
  }

  List<ChatOutgoingMediaEntity?> getAllByOwnerCidNumberPendingKeySync(
      List<String> ownerCidNumberValues, List<String> pendingKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(pendingKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], pendingKeyValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_pendingKey', values);
  }

  Future<int> deleteAllByOwnerCidNumberPendingKey(
      List<String> ownerCidNumberValues, List<String> pendingKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(pendingKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], pendingKeyValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_pendingKey', values);
  }

  int deleteAllByOwnerCidNumberPendingKeySync(
      List<String> ownerCidNumberValues, List<String> pendingKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(pendingKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], pendingKeyValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_pendingKey', values);
  }

  Future<Id> putByOwnerCidNumberPendingKey(ChatOutgoingMediaEntity object) {
    return putByIndex(r'ownerCidNumber_pendingKey', object);
  }

  Id putByOwnerCidNumberPendingKeySync(ChatOutgoingMediaEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_pendingKey', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberPendingKey(
      List<ChatOutgoingMediaEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_pendingKey', objects);
  }

  List<Id> putAllByOwnerCidNumberPendingKeySync(
      List<ChatOutgoingMediaEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_pendingKey', objects,
        saveLinks: saveLinks);
  }
}

extension ChatOutgoingMediaEntityQueryWhereSort
    on QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QWhere> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatOutgoingMediaEntityQueryWhere on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QWhereClause> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToAnyPendingKey(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_pendingKey',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterWhereClause>
      ownerCidNumberNotEqualToAnyPendingKey(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterWhereClause>
      ownerCidNumberPendingKeyEqualTo(
          String ownerCidNumber, String pendingKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_pendingKey',
        value: [ownerCidNumber, pendingKey],
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToPendingKeyNotEqualTo(
          String ownerCidNumber, String pendingKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, pendingKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber, pendingKey],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber, pendingKey],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_pendingKey',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, pendingKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> attachmentIdEqualTo(String attachmentId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'attachmentId',
        value: [attachmentId],
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> attachmentIdNotEqualTo(String attachmentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attachmentId',
              lower: [],
              upper: [attachmentId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attachmentId',
              lower: [attachmentId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attachmentId',
              lower: [attachmentId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'attachmentId',
              lower: [],
              upper: [attachmentId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterWhereClause> recipientCidNumberEqualTo(String recipientCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'recipientCidNumber',
        value: [recipientCidNumber],
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterWhereClause>
      recipientCidNumberNotEqualTo(String recipientCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipientCidNumber',
              lower: [],
              upper: [recipientCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipientCidNumber',
              lower: [recipientCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipientCidNumber',
              lower: [recipientCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'recipientCidNumber',
              lower: [],
              upper: [recipientCidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatOutgoingMediaEntityQueryFilter on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QFilterCondition> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attachmentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      attachmentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'attachmentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      attachmentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'attachmentId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attachmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> attachmentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'attachmentId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> byteSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> byteSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> byteSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'byteSize',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> byteSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'byteSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      contentTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      contentTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentType',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> contentTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentType',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fileName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      fileNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      fileNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fileName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fileName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> fileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fileName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pendingKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      pendingKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pendingKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      pendingKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pendingKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> pendingKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pendingKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'recipientCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      recipientCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'recipientCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
          QAfterFilterCondition>
      recipientCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'recipientCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity,
      QAfterFilterCondition> recipientCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'recipientCidNumber',
        value: '',
      ));
    });
  }
}

extension ChatOutgoingMediaEntityQueryObject on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QFilterCondition> {}

extension ChatOutgoingMediaEntityQueryLinks on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QFilterCondition> {}

extension ChatOutgoingMediaEntityQuerySortBy
    on QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QSortBy> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByAttachmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByAttachmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentType', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentType', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileName', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileName', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByPendingKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingKey', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByPendingKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingKey', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      sortByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }
}

extension ChatOutgoingMediaEntityQuerySortThenBy on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QSortThenBy> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByAttachmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByAttachmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byteSize', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentType', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentType', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileName', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileName', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByPendingKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingKey', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByPendingKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingKey', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByRecipientCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
      thenByRecipientCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipientCidNumber', Sort.desc);
    });
  }
}

extension ChatOutgoingMediaEntityQueryWhereDistinct on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByAttachmentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'byteSize');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByContentType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByFileName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fileName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByPendingKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
      distinctByRecipientCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipientCidNumber',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChatOutgoingMediaEntityQueryProperty on QueryBuilder<
    ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QQueryProperty> {
  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      attachmentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentId');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations>
      byteSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'byteSize');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      contentTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentType');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      fileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileName');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      pendingKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingKey');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
      recipientCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipientCidNumber');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatPendingInboundEntityCollection on Isar {
  IsarCollection<ChatPendingInboundEntity> get chatPendingInboundEntitys =>
      this.collection();
}

const ChatPendingInboundEntitySchema = CollectionSchema(
  name: r'ChatPendingInboundEntity',
  id: -5074141936840117970,
  properties: {
    r'conversationId': PropertySchema(
      id: 0,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'createdAtMillis': PropertySchema(
      id: 1,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'envelopeBytesHex': PropertySchema(
      id: 2,
      name: r'envelopeBytesHex',
      type: IsarType.string,
    ),
    r'envelopeId': PropertySchema(
      id: 3,
      name: r'envelopeId',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 4,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'reason': PropertySchema(
      id: 5,
      name: r'reason',
      type: IsarType.string,
    )
  },
  estimateSize: _chatPendingInboundEntityEstimateSize,
  serialize: _chatPendingInboundEntitySerialize,
  deserialize: _chatPendingInboundEntityDeserialize,
  deserializeProp: _chatPendingInboundEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_envelopeId': IndexSchema(
      id: 3891964785492803984,
      name: r'ownerCidNumber_envelopeId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'envelopeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAtMillis': IndexSchema(
      id: -2739706252225730577,
      name: r'createdAtMillis',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAtMillis',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatPendingInboundEntityGetId,
  getLinks: _chatPendingInboundEntityGetLinks,
  attach: _chatPendingInboundEntityAttach,
  version: '3.3.2',
);

int _chatPendingInboundEntityEstimateSize(
  ChatPendingInboundEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.envelopeBytesHex.length * 3;
  bytesCount += 3 + object.envelopeId.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.reason.length * 3;
  return bytesCount;
}

void _chatPendingInboundEntitySerialize(
  ChatPendingInboundEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conversationId);
  writer.writeLong(offsets[1], object.createdAtMillis);
  writer.writeString(offsets[2], object.envelopeBytesHex);
  writer.writeString(offsets[3], object.envelopeId);
  writer.writeString(offsets[4], object.ownerCidNumber);
  writer.writeString(offsets[5], object.reason);
}

ChatPendingInboundEntity _chatPendingInboundEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatPendingInboundEntity();
  object.conversationId = reader.readString(offsets[0]);
  object.createdAtMillis = reader.readLong(offsets[1]);
  object.envelopeBytesHex = reader.readString(offsets[2]);
  object.envelopeId = reader.readString(offsets[3]);
  object.id = id;
  object.ownerCidNumber = reader.readString(offsets[4]);
  object.reason = reader.readString(offsets[5]);
  return object;
}

P _chatPendingInboundEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatPendingInboundEntityGetId(ChatPendingInboundEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatPendingInboundEntityGetLinks(
    ChatPendingInboundEntity object) {
  return [];
}

void _chatPendingInboundEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatPendingInboundEntity object) {
  object.id = id;
}

extension ChatPendingInboundEntityByIndex
    on IsarCollection<ChatPendingInboundEntity> {
  Future<ChatPendingInboundEntity?> getByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return getByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  ChatPendingInboundEntity? getByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return getByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<bool> deleteByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  bool deleteByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<List<ChatPendingInboundEntity?>> getAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  List<ChatPendingInboundEntity?> getAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<int> deleteAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  int deleteAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<Id> putByOwnerCidNumberEnvelopeId(ChatPendingInboundEntity object) {
    return putByIndex(r'ownerCidNumber_envelopeId', object);
  }

  Id putByOwnerCidNumberEnvelopeIdSync(ChatPendingInboundEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_envelopeId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberEnvelopeId(
      List<ChatPendingInboundEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_envelopeId', objects);
  }

  List<Id> putAllByOwnerCidNumberEnvelopeIdSync(
      List<ChatPendingInboundEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_envelopeId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatPendingInboundEntityQueryWhereSort on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QWhere> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterWhere>
      anyCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAtMillis'),
      );
    });
  }
}

extension ChatPendingInboundEntityQueryWhere on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QWhereClause> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterWhereClause>
      ownerCidNumberNotEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterWhereClause>
      ownerCidNumberEnvelopeIdEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber, envelopeId],
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToEnvelopeIdNotEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conversationId',
        value: [conversationId],
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> createdAtMillisEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAtMillis',
        value: [createdAtMillis],
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> createdAtMillisNotEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [],
              upper: [createdAtMillis],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [createdAtMillis],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [createdAtMillis],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAtMillis',
              lower: [],
              upper: [createdAtMillis],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> createdAtMillisGreaterThan(
    int createdAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [createdAtMillis],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> createdAtMillisLessThan(
    int createdAtMillis, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [],
        upper: [createdAtMillis],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterWhereClause> createdAtMillisBetween(
    int lowerCreatedAtMillis,
    int upperCreatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAtMillis',
        lower: [lowerCreatedAtMillis],
        includeLower: includeLower,
        upper: [upperCreatedAtMillis],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatPendingInboundEntityQueryFilter on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QFilterCondition> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeBytesHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      envelopeBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      envelopeBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeBytesHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      envelopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      envelopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> envelopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      reasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
          QAfterFilterCondition>
      reasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity,
      QAfterFilterCondition> reasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reason',
        value: '',
      ));
    });
  }
}

extension ChatPendingInboundEntityQueryObject on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QFilterCondition> {}

extension ChatPendingInboundEntityQueryLinks on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QFilterCondition> {}

extension ChatPendingInboundEntityQuerySortBy on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QSortBy> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      sortByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }
}

extension ChatPendingInboundEntityQuerySortThenBy on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QSortThenBy> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
      thenByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }
}

extension ChatPendingInboundEntityQueryWhereDistinct on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct> {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByEnvelopeBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeBytesHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByEnvelopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
      distinctByReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reason', caseSensitive: caseSensitive);
    });
  }
}

extension ChatPendingInboundEntityQueryProperty on QueryBuilder<
    ChatPendingInboundEntity, ChatPendingInboundEntity, QQueryProperty> {
  QueryBuilder<ChatPendingInboundEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
      conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
      envelopeBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeBytesHex');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
      envelopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeId');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
      reasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reason');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatRouteCacheEntityCollection on Isar {
  IsarCollection<ChatRouteCacheEntity> get chatRouteCacheEntitys =>
      this.collection();
}

const ChatRouteCacheEntitySchema = CollectionSchema(
  name: r'ChatRouteCacheEntity',
  id: -1879395959909772186,
  properties: {
    r'createdAtMillis': PropertySchema(
      id: 0,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'deviceId': PropertySchema(
      id: 1,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'devicePublicKey': PropertySchema(
      id: 2,
      name: r'devicePublicKey',
      type: IsarType.string,
    ),
    r'nearbyPeerHint': PropertySchema(
      id: 3,
      name: r'nearbyPeerHint',
      type: IsarType.string,
    ),
    r'note': PropertySchema(
      id: 4,
      name: r'note',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 5,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'peerCidNumber': PropertySchema(
      id: 6,
      name: r'peerCidNumber',
      type: IsarType.string,
    ),
    r'routeDisplayName': PropertySchema(
      id: 7,
      name: r'routeDisplayName',
      type: IsarType.string,
    ),
    r'safetyNumber': PropertySchema(
      id: 8,
      name: r'safetyNumber',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 9,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _chatRouteCacheEntityEstimateSize,
  serialize: _chatRouteCacheEntitySerialize,
  deserialize: _chatRouteCacheEntityDeserialize,
  deserializeProp: _chatRouteCacheEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_peerCidNumber': IndexSchema(
      id: -3106889458447634706,
      name: r'ownerCidNumber_peerCidNumber',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'peerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatRouteCacheEntityGetId,
  getLinks: _chatRouteCacheEntityGetLinks,
  attach: _chatRouteCacheEntityAttach,
  version: '3.3.2',
);

int _chatRouteCacheEntityEstimateSize(
  ChatRouteCacheEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.deviceId.length * 3;
  bytesCount += 3 + object.devicePublicKey.length * 3;
  {
    final value = object.nearbyPeerHint;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.peerCidNumber.length * 3;
  bytesCount += 3 + object.routeDisplayName.length * 3;
  bytesCount += 3 + object.safetyNumber.length * 3;
  return bytesCount;
}

void _chatRouteCacheEntitySerialize(
  ChatRouteCacheEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.deviceId);
  writer.writeString(offsets[2], object.devicePublicKey);
  writer.writeString(offsets[3], object.nearbyPeerHint);
  writer.writeString(offsets[4], object.note);
  writer.writeString(offsets[5], object.ownerCidNumber);
  writer.writeString(offsets[6], object.peerCidNumber);
  writer.writeString(offsets[7], object.routeDisplayName);
  writer.writeString(offsets[8], object.safetyNumber);
  writer.writeLong(offsets[9], object.updatedAtMillis);
}

ChatRouteCacheEntity _chatRouteCacheEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatRouteCacheEntity();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.deviceId = reader.readString(offsets[1]);
  object.devicePublicKey = reader.readString(offsets[2]);
  object.id = id;
  object.nearbyPeerHint = reader.readStringOrNull(offsets[3]);
  object.note = reader.readStringOrNull(offsets[4]);
  object.ownerCidNumber = reader.readString(offsets[5]);
  object.peerCidNumber = reader.readString(offsets[6]);
  object.routeDisplayName = reader.readString(offsets[7]);
  object.safetyNumber = reader.readString(offsets[8]);
  object.updatedAtMillis = reader.readLong(offsets[9]);
  return object;
}

P _chatRouteCacheEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatRouteCacheEntityGetId(ChatRouteCacheEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatRouteCacheEntityGetLinks(
    ChatRouteCacheEntity object) {
  return [];
}

void _chatRouteCacheEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatRouteCacheEntity object) {
  object.id = id;
}

extension ChatRouteCacheEntityByIndex on IsarCollection<ChatRouteCacheEntity> {
  Future<ChatRouteCacheEntity?> getByOwnerCidNumberPeerCidNumber(
      String ownerCidNumber, String peerCidNumber) {
    return getByIndex(
        r'ownerCidNumber_peerCidNumber', [ownerCidNumber, peerCidNumber]);
  }

  ChatRouteCacheEntity? getByOwnerCidNumberPeerCidNumberSync(
      String ownerCidNumber, String peerCidNumber) {
    return getByIndexSync(
        r'ownerCidNumber_peerCidNumber', [ownerCidNumber, peerCidNumber]);
  }

  Future<bool> deleteByOwnerCidNumberPeerCidNumber(
      String ownerCidNumber, String peerCidNumber) {
    return deleteByIndex(
        r'ownerCidNumber_peerCidNumber', [ownerCidNumber, peerCidNumber]);
  }

  bool deleteByOwnerCidNumberPeerCidNumberSync(
      String ownerCidNumber, String peerCidNumber) {
    return deleteByIndexSync(
        r'ownerCidNumber_peerCidNumber', [ownerCidNumber, peerCidNumber]);
  }

  Future<List<ChatRouteCacheEntity?>> getAllByOwnerCidNumberPeerCidNumber(
      List<String> ownerCidNumberValues, List<String> peerCidNumberValues) {
    final len = ownerCidNumberValues.length;
    assert(peerCidNumberValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], peerCidNumberValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_peerCidNumber', values);
  }

  List<ChatRouteCacheEntity?> getAllByOwnerCidNumberPeerCidNumberSync(
      List<String> ownerCidNumberValues, List<String> peerCidNumberValues) {
    final len = ownerCidNumberValues.length;
    assert(peerCidNumberValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], peerCidNumberValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_peerCidNumber', values);
  }

  Future<int> deleteAllByOwnerCidNumberPeerCidNumber(
      List<String> ownerCidNumberValues, List<String> peerCidNumberValues) {
    final len = ownerCidNumberValues.length;
    assert(peerCidNumberValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], peerCidNumberValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_peerCidNumber', values);
  }

  int deleteAllByOwnerCidNumberPeerCidNumberSync(
      List<String> ownerCidNumberValues, List<String> peerCidNumberValues) {
    final len = ownerCidNumberValues.length;
    assert(peerCidNumberValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], peerCidNumberValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_peerCidNumber', values);
  }

  Future<Id> putByOwnerCidNumberPeerCidNumber(ChatRouteCacheEntity object) {
    return putByIndex(r'ownerCidNumber_peerCidNumber', object);
  }

  Id putByOwnerCidNumberPeerCidNumberSync(ChatRouteCacheEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_peerCidNumber', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberPeerCidNumber(
      List<ChatRouteCacheEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_peerCidNumber', objects);
  }

  List<Id> putAllByOwnerCidNumberPeerCidNumberSync(
      List<ChatRouteCacheEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_peerCidNumber', objects,
        saveLinks: saveLinks);
  }
}

extension ChatRouteCacheEntityQueryWhereSort
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QWhere> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatRouteCacheEntityQueryWhere
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QWhereClause> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      ownerCidNumberEqualToAnyPeerCidNumber(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_peerCidNumber',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      ownerCidNumberNotEqualToAnyPeerCidNumber(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      ownerCidNumberPeerCidNumberEqualTo(
          String ownerCidNumber, String peerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_peerCidNumber',
        value: [ownerCidNumber, peerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
      ownerCidNumberEqualToPeerCidNumberNotEqualTo(
          String ownerCidNumber, String peerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, peerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber, peerCidNumber],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber, peerCidNumber],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_peerCidNumber',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, peerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatRouteCacheEntityQueryFilter on QueryBuilder<ChatRouteCacheEntity,
    ChatRouteCacheEntity, QFilterCondition> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'devicePublicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      devicePublicKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'devicePublicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      devicePublicKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'devicePublicKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'devicePublicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> devicePublicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'devicePublicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'nearbyPeerHint',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'nearbyPeerHint',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nearbyPeerHint',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      nearbyPeerHintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nearbyPeerHint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      nearbyPeerHintMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nearbyPeerHint',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nearbyPeerHint',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> nearbyPeerHintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nearbyPeerHint',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'peerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      peerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'peerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      peerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'peerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> peerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'peerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routeDisplayName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      routeDisplayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routeDisplayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      routeDisplayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routeDisplayName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeDisplayName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> routeDisplayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routeDisplayName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      safetyNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
          QAfterFilterCondition>
      safetyNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> safetyNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> updatedAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> updatedAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity,
      QAfterFilterCondition> updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatRouteCacheEntityQueryObject on QueryBuilder<ChatRouteCacheEntity,
    ChatRouteCacheEntity, QFilterCondition> {}

extension ChatRouteCacheEntityQueryLinks on QueryBuilder<ChatRouteCacheEntity,
    ChatRouteCacheEntity, QFilterCondition> {}

extension ChatRouteCacheEntityQuerySortBy
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QSortBy> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByDevicePublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'devicePublicKey', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByDevicePublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'devicePublicKey', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByNearbyPeerHint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearbyPeerHint', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByNearbyPeerHintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearbyPeerHint', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByPeerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByPeerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByRouteDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDisplayName', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByRouteDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDisplayName', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortBySafetyNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortBySafetyNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatRouteCacheEntityQuerySortThenBy
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QSortThenBy> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByDevicePublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'devicePublicKey', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByDevicePublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'devicePublicKey', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByNearbyPeerHint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearbyPeerHint', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByNearbyPeerHintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearbyPeerHint', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByPeerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByPeerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByRouteDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDisplayName', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByRouteDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDisplayName', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenBySafetyNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenBySafetyNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatRouteCacheEntityQueryWhereDistinct
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByDevicePublicKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'devicePublicKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByNearbyPeerHint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nearbyPeerHint',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByPeerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByRouteDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routeDisplayName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctBySafetyNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension ChatRouteCacheEntityQueryProperty on QueryBuilder<
    ChatRouteCacheEntity, ChatRouteCacheEntity, QQueryProperty> {
  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      devicePublicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'devicePublicKey');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String?, QQueryOperations>
      nearbyPeerHintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nearbyPeerHint');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      peerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peerCidNumber');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      routeDisplayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routeDisplayName');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
      safetyNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyNumber');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupEntityCollection on Isar {
  IsarCollection<ChatGroupEntity> get chatGroupEntitys => this.collection();
}

const ChatGroupEntitySchema = CollectionSchema(
  name: r'ChatGroupEntity',
  id: 6599995462947761436,
  properties: {
    r'createdAtMillis': PropertySchema(
      id: 0,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'creatorCidNumber': PropertySchema(
      id: 1,
      name: r'creatorCidNumber',
      type: IsarType.string,
    ),
    r'epoch': PropertySchema(
      id: 2,
      name: r'epoch',
      type: IsarType.long,
    ),
    r'groupId': PropertySchema(
      id: 3,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'groupName': PropertySchema(
      id: 4,
      name: r'groupName',
      type: IsarType.string,
    ),
    r'leftLocally': PropertySchema(
      id: 5,
      name: r'leftLocally',
      type: IsarType.bool,
    ),
    r'memberCount': PropertySchema(
      id: 6,
      name: r'memberCount',
      type: IsarType.long,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 7,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 8,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _chatGroupEntityEstimateSize,
  serialize: _chatGroupEntitySerialize,
  deserialize: _chatGroupEntityDeserialize,
  deserializeProp: _chatGroupEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_groupId': IndexSchema(
      id: 2593890677711017874,
      name: r'ownerCidNumber_groupId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatGroupEntityGetId,
  getLinks: _chatGroupEntityGetLinks,
  attach: _chatGroupEntityAttach,
  version: '3.3.2',
);

int _chatGroupEntityEstimateSize(
  ChatGroupEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.creatorCidNumber.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.groupName.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  return bytesCount;
}

void _chatGroupEntitySerialize(
  ChatGroupEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.creatorCidNumber);
  writer.writeLong(offsets[2], object.epoch);
  writer.writeString(offsets[3], object.groupId);
  writer.writeString(offsets[4], object.groupName);
  writer.writeBool(offsets[5], object.leftLocally);
  writer.writeLong(offsets[6], object.memberCount);
  writer.writeString(offsets[7], object.ownerCidNumber);
  writer.writeLong(offsets[8], object.updatedAtMillis);
}

ChatGroupEntity _chatGroupEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupEntity();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.creatorCidNumber = reader.readString(offsets[1]);
  object.epoch = reader.readLong(offsets[2]);
  object.groupId = reader.readString(offsets[3]);
  object.groupName = reader.readString(offsets[4]);
  object.id = id;
  object.leftLocally = reader.readBool(offsets[5]);
  object.memberCount = reader.readLong(offsets[6]);
  object.ownerCidNumber = reader.readString(offsets[7]);
  object.updatedAtMillis = reader.readLong(offsets[8]);
  return object;
}

P _chatGroupEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupEntityGetId(ChatGroupEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupEntityGetLinks(ChatGroupEntity object) {
  return [];
}

void _chatGroupEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatGroupEntity object) {
  object.id = id;
}

extension ChatGroupEntityByIndex on IsarCollection<ChatGroupEntity> {
  Future<ChatGroupEntity?> getByOwnerCidNumberGroupId(
      String ownerCidNumber, String groupId) {
    return getByIndex(r'ownerCidNumber_groupId', [ownerCidNumber, groupId]);
  }

  ChatGroupEntity? getByOwnerCidNumberGroupIdSync(
      String ownerCidNumber, String groupId) {
    return getByIndexSync(r'ownerCidNumber_groupId', [ownerCidNumber, groupId]);
  }

  Future<bool> deleteByOwnerCidNumberGroupId(
      String ownerCidNumber, String groupId) {
    return deleteByIndex(r'ownerCidNumber_groupId', [ownerCidNumber, groupId]);
  }

  bool deleteByOwnerCidNumberGroupIdSync(
      String ownerCidNumber, String groupId) {
    return deleteByIndexSync(
        r'ownerCidNumber_groupId', [ownerCidNumber, groupId]);
  }

  Future<List<ChatGroupEntity?>> getAllByOwnerCidNumberGroupId(
      List<String> ownerCidNumberValues, List<String> groupIdValues) {
    final len = ownerCidNumberValues.length;
    assert(groupIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], groupIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_groupId', values);
  }

  List<ChatGroupEntity?> getAllByOwnerCidNumberGroupIdSync(
      List<String> ownerCidNumberValues, List<String> groupIdValues) {
    final len = ownerCidNumberValues.length;
    assert(groupIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], groupIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_groupId', values);
  }

  Future<int> deleteAllByOwnerCidNumberGroupId(
      List<String> ownerCidNumberValues, List<String> groupIdValues) {
    final len = ownerCidNumberValues.length;
    assert(groupIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], groupIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_groupId', values);
  }

  int deleteAllByOwnerCidNumberGroupIdSync(
      List<String> ownerCidNumberValues, List<String> groupIdValues) {
    final len = ownerCidNumberValues.length;
    assert(groupIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], groupIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_groupId', values);
  }

  Future<Id> putByOwnerCidNumberGroupId(ChatGroupEntity object) {
    return putByIndex(r'ownerCidNumber_groupId', object);
  }

  Id putByOwnerCidNumberGroupIdSync(ChatGroupEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_groupId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberGroupId(
      List<ChatGroupEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_groupId', objects);
  }

  List<Id> putAllByOwnerCidNumberGroupIdSync(List<ChatGroupEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_groupId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatGroupEntityQueryWhereSort
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QWhere> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatGroupEntityQueryWhere
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QWhereClause> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      ownerCidNumberEqualToAnyGroupId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_groupId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      ownerCidNumberNotEqualToAnyGroupId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      ownerCidNumberGroupIdEqualTo(String ownerCidNumber, String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_groupId',
        value: [ownerCidNumber, groupId],
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
      ownerCidNumberEqualToGroupIdNotEqualTo(
          String ownerCidNumber, String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, groupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber, groupId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber, groupId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_groupId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, groupId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatGroupEntityQueryFilter
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'creatorCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'creatorCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'creatorCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'creatorCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      creatorCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'creatorCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      epochEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'epoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      epochGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'epoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      epochLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'epoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      epochBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'epoch',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      groupNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupName',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      leftLocallyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'leftLocally',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      memberCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      memberCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'memberCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      memberCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'memberCount',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      memberCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'memberCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      updatedAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      updatedAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
      updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatGroupEntityQueryObject
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {}

extension ChatGroupEntityQueryLinks
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {}

extension ChatGroupEntityQuerySortBy
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QSortBy> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByCreatorCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByCreatorCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> sortByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'epoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'epoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupName', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupName', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'leftLocally', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByLeftLocallyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'leftLocally', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByMemberCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatGroupEntityQuerySortThenBy
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QSortThenBy> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByCreatorCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByCreatorCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creatorCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'epoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'epoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupName', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupName', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'leftLocally', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByLeftLocallyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'leftLocally', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByMemberCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension ChatGroupEntityQueryWhereDistinct
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByCreatorCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'creatorCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> distinctByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'epoch');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> distinctByGroupId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> distinctByGroupName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'leftLocally');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberCount');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension ChatGroupEntityQueryProperty
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QQueryProperty> {
  QueryBuilder<ChatGroupEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations>
      creatorCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'creatorCidNumber');
    });
  }

  QueryBuilder<ChatGroupEntity, int, QQueryOperations> epochProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'epoch');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations> groupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupName');
    });
  }

  QueryBuilder<ChatGroupEntity, bool, QQueryOperations> leftLocallyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'leftLocally');
    });
  }

  QueryBuilder<ChatGroupEntity, int, QQueryOperations> memberCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberCount');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatGroupEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupMemberEntityCollection on Isar {
  IsarCollection<ChatGroupMemberEntity> get chatGroupMemberEntitys =>
      this.collection();
}

const ChatGroupMemberEntitySchema = CollectionSchema(
  name: r'ChatGroupMemberEntity',
  id: 2209953071771450672,
  properties: {
    r'groupId': PropertySchema(
      id: 0,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'joinedAtMillis': PropertySchema(
      id: 1,
      name: r'joinedAtMillis',
      type: IsarType.long,
    ),
    r'memberCidNumber': PropertySchema(
      id: 2,
      name: r'memberCidNumber',
      type: IsarType.string,
    ),
    r'memberKey': PropertySchema(
      id: 3,
      name: r'memberKey',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 4,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'role': PropertySchema(
      id: 5,
      name: r'role',
      type: IsarType.string,
    )
  },
  estimateSize: _chatGroupMemberEntityEstimateSize,
  serialize: _chatGroupMemberEntitySerialize,
  deserialize: _chatGroupMemberEntityDeserialize,
  deserializeProp: _chatGroupMemberEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_memberKey': IndexSchema(
      id: -6851219256754649152,
      name: r'ownerCidNumber_memberKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'memberKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatGroupMemberEntityGetId,
  getLinks: _chatGroupMemberEntityGetLinks,
  attach: _chatGroupMemberEntityAttach,
  version: '3.3.2',
);

int _chatGroupMemberEntityEstimateSize(
  ChatGroupMemberEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.memberCidNumber.length * 3;
  bytesCount += 3 + object.memberKey.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.role.length * 3;
  return bytesCount;
}

void _chatGroupMemberEntitySerialize(
  ChatGroupMemberEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.groupId);
  writer.writeLong(offsets[1], object.joinedAtMillis);
  writer.writeString(offsets[2], object.memberCidNumber);
  writer.writeString(offsets[3], object.memberKey);
  writer.writeString(offsets[4], object.ownerCidNumber);
  writer.writeString(offsets[5], object.role);
}

ChatGroupMemberEntity _chatGroupMemberEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupMemberEntity();
  object.groupId = reader.readString(offsets[0]);
  object.id = id;
  object.joinedAtMillis = reader.readLong(offsets[1]);
  object.memberCidNumber = reader.readString(offsets[2]);
  object.memberKey = reader.readString(offsets[3]);
  object.ownerCidNumber = reader.readString(offsets[4]);
  object.role = reader.readString(offsets[5]);
  return object;
}

P _chatGroupMemberEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupMemberEntityGetId(ChatGroupMemberEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupMemberEntityGetLinks(
    ChatGroupMemberEntity object) {
  return [];
}

void _chatGroupMemberEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatGroupMemberEntity object) {
  object.id = id;
}

extension ChatGroupMemberEntityByIndex
    on IsarCollection<ChatGroupMemberEntity> {
  Future<ChatGroupMemberEntity?> getByOwnerCidNumberMemberKey(
      String ownerCidNumber, String memberKey) {
    return getByIndex(r'ownerCidNumber_memberKey', [ownerCidNumber, memberKey]);
  }

  ChatGroupMemberEntity? getByOwnerCidNumberMemberKeySync(
      String ownerCidNumber, String memberKey) {
    return getByIndexSync(
        r'ownerCidNumber_memberKey', [ownerCidNumber, memberKey]);
  }

  Future<bool> deleteByOwnerCidNumberMemberKey(
      String ownerCidNumber, String memberKey) {
    return deleteByIndex(
        r'ownerCidNumber_memberKey', [ownerCidNumber, memberKey]);
  }

  bool deleteByOwnerCidNumberMemberKeySync(
      String ownerCidNumber, String memberKey) {
    return deleteByIndexSync(
        r'ownerCidNumber_memberKey', [ownerCidNumber, memberKey]);
  }

  Future<List<ChatGroupMemberEntity?>> getAllByOwnerCidNumberMemberKey(
      List<String> ownerCidNumberValues, List<String> memberKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(memberKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], memberKeyValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_memberKey', values);
  }

  List<ChatGroupMemberEntity?> getAllByOwnerCidNumberMemberKeySync(
      List<String> ownerCidNumberValues, List<String> memberKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(memberKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], memberKeyValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_memberKey', values);
  }

  Future<int> deleteAllByOwnerCidNumberMemberKey(
      List<String> ownerCidNumberValues, List<String> memberKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(memberKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], memberKeyValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_memberKey', values);
  }

  int deleteAllByOwnerCidNumberMemberKeySync(
      List<String> ownerCidNumberValues, List<String> memberKeyValues) {
    final len = ownerCidNumberValues.length;
    assert(memberKeyValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], memberKeyValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_memberKey', values);
  }

  Future<Id> putByOwnerCidNumberMemberKey(ChatGroupMemberEntity object) {
    return putByIndex(r'ownerCidNumber_memberKey', object);
  }

  Id putByOwnerCidNumberMemberKeySync(ChatGroupMemberEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_memberKey', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberMemberKey(
      List<ChatGroupMemberEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_memberKey', objects);
  }

  List<Id> putAllByOwnerCidNumberMemberKeySync(
      List<ChatGroupMemberEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_memberKey', objects,
        saveLinks: saveLinks);
  }
}

extension ChatGroupMemberEntityQueryWhereSort
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QWhere> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatGroupMemberEntityQueryWhere on QueryBuilder<ChatGroupMemberEntity,
    ChatGroupMemberEntity, QWhereClause> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      ownerCidNumberEqualToAnyMemberKey(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_memberKey',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      ownerCidNumberNotEqualToAnyMemberKey(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      ownerCidNumberMemberKeyEqualTo(String ownerCidNumber, String memberKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_memberKey',
        value: [ownerCidNumber, memberKey],
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      ownerCidNumberEqualToMemberKeyNotEqualTo(
          String ownerCidNumber, String memberKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, memberKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber, memberKey],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber, memberKey],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_memberKey',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, memberKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupId',
        value: [groupId],
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
      groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatGroupMemberEntityQueryFilter on QueryBuilder<
    ChatGroupMemberEntity, ChatGroupMemberEntity, QFilterCondition> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> joinedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'joinedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> joinedAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'joinedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> joinedAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'joinedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> joinedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'joinedAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'memberCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      memberCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'memberCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      memberCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'memberCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'memberCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'memberKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      memberKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'memberKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      memberKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'memberKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'memberKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> memberKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'memberKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'role',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      roleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'role',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
          QAfterFilterCondition>
      roleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'role',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'role',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity,
      QAfterFilterCondition> roleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'role',
        value: '',
      ));
    });
  }
}

extension ChatGroupMemberEntityQueryObject on QueryBuilder<
    ChatGroupMemberEntity, ChatGroupMemberEntity, QFilterCondition> {}

extension ChatGroupMemberEntityQueryLinks on QueryBuilder<ChatGroupMemberEntity,
    ChatGroupMemberEntity, QFilterCondition> {}

extension ChatGroupMemberEntityQuerySortBy
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QSortBy> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByJoinedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByJoinedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByMemberCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByMemberCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByMemberKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByMemberKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'role', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      sortByRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'role', Sort.desc);
    });
  }
}

extension ChatGroupMemberEntityQuerySortThenBy
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QSortThenBy> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByJoinedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByJoinedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByMemberCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByMemberCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByMemberKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByMemberKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberKey', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'role', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
      thenByRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'role', Sort.desc);
    });
  }
}

extension ChatGroupMemberEntityQueryWhereDistinct
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByJoinedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'joinedAtMillis');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByMemberCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByMemberKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
      distinctByRole({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'role', caseSensitive: caseSensitive);
    });
  }
}

extension ChatGroupMemberEntityQueryProperty on QueryBuilder<
    ChatGroupMemberEntity, ChatGroupMemberEntity, QQueryProperty> {
  QueryBuilder<ChatGroupMemberEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
      groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, int, QQueryOperations>
      joinedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'joinedAtMillis');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
      memberCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberCidNumber');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
      memberKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberKey');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations> roleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'role');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupPendingCommitEntityCollection on Isar {
  IsarCollection<ChatGroupPendingCommitEntity>
      get chatGroupPendingCommitEntitys => this.collection();
}

const ChatGroupPendingCommitEntitySchema = CollectionSchema(
  name: r'ChatGroupPendingCommitEntity',
  id: 4467971278504501601,
  properties: {
    r'createdAtMillis': PropertySchema(
      id: 0,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'envelopeBytesHex': PropertySchema(
      id: 1,
      name: r'envelopeBytesHex',
      type: IsarType.string,
    ),
    r'envelopeId': PropertySchema(
      id: 2,
      name: r'envelopeId',
      type: IsarType.string,
    ),
    r'groupId': PropertySchema(
      id: 3,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'messageEpoch': PropertySchema(
      id: 4,
      name: r'messageEpoch',
      type: IsarType.long,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 5,
      name: r'ownerCidNumber',
      type: IsarType.string,
    )
  },
  estimateSize: _chatGroupPendingCommitEntityEstimateSize,
  serialize: _chatGroupPendingCommitEntitySerialize,
  deserialize: _chatGroupPendingCommitEntityDeserialize,
  deserializeProp: _chatGroupPendingCommitEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber_envelopeId': IndexSchema(
      id: 3891964785492803984,
      name: r'ownerCidNumber_envelopeId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'envelopeId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'messageEpoch': IndexSchema(
      id: 2696323681374748078,
      name: r'messageEpoch',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'messageEpoch',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatGroupPendingCommitEntityGetId,
  getLinks: _chatGroupPendingCommitEntityGetLinks,
  attach: _chatGroupPendingCommitEntityAttach,
  version: '3.3.2',
);

int _chatGroupPendingCommitEntityEstimateSize(
  ChatGroupPendingCommitEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.envelopeBytesHex.length * 3;
  bytesCount += 3 + object.envelopeId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  return bytesCount;
}

void _chatGroupPendingCommitEntitySerialize(
  ChatGroupPendingCommitEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.envelopeBytesHex);
  writer.writeString(offsets[2], object.envelopeId);
  writer.writeString(offsets[3], object.groupId);
  writer.writeLong(offsets[4], object.messageEpoch);
  writer.writeString(offsets[5], object.ownerCidNumber);
}

ChatGroupPendingCommitEntity _chatGroupPendingCommitEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupPendingCommitEntity();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.envelopeBytesHex = reader.readString(offsets[1]);
  object.envelopeId = reader.readString(offsets[2]);
  object.groupId = reader.readString(offsets[3]);
  object.id = id;
  object.messageEpoch = reader.readLong(offsets[4]);
  object.ownerCidNumber = reader.readString(offsets[5]);
  return object;
}

P _chatGroupPendingCommitEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupPendingCommitEntityGetId(ChatGroupPendingCommitEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupPendingCommitEntityGetLinks(
    ChatGroupPendingCommitEntity object) {
  return [];
}

void _chatGroupPendingCommitEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatGroupPendingCommitEntity object) {
  object.id = id;
}

extension ChatGroupPendingCommitEntityByIndex
    on IsarCollection<ChatGroupPendingCommitEntity> {
  Future<ChatGroupPendingCommitEntity?> getByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return getByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  ChatGroupPendingCommitEntity? getByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return getByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<bool> deleteByOwnerCidNumberEnvelopeId(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndex(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  bool deleteByOwnerCidNumberEnvelopeIdSync(
      String ownerCidNumber, String envelopeId) {
    return deleteByIndexSync(
        r'ownerCidNumber_envelopeId', [ownerCidNumber, envelopeId]);
  }

  Future<List<ChatGroupPendingCommitEntity?>> getAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  List<ChatGroupPendingCommitEntity?> getAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return getAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<int> deleteAllByOwnerCidNumberEnvelopeId(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndex(r'ownerCidNumber_envelopeId', values);
  }

  int deleteAllByOwnerCidNumberEnvelopeIdSync(
      List<String> ownerCidNumberValues, List<String> envelopeIdValues) {
    final len = ownerCidNumberValues.length;
    assert(envelopeIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerCidNumberValues[i], envelopeIdValues[i]]);
    }

    return deleteAllByIndexSync(r'ownerCidNumber_envelopeId', values);
  }

  Future<Id> putByOwnerCidNumberEnvelopeId(
      ChatGroupPendingCommitEntity object) {
    return putByIndex(r'ownerCidNumber_envelopeId', object);
  }

  Id putByOwnerCidNumberEnvelopeIdSync(ChatGroupPendingCommitEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber_envelopeId', object,
        saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumberEnvelopeId(
      List<ChatGroupPendingCommitEntity> objects) {
    return putAllByIndex(r'ownerCidNumber_envelopeId', objects);
  }

  List<Id> putAllByOwnerCidNumberEnvelopeIdSync(
      List<ChatGroupPendingCommitEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber_envelopeId', objects,
        saveLinks: saveLinks);
  }
}

extension ChatGroupPendingCommitEntityQueryWhereSort on QueryBuilder<
    ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity, QWhere> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhere> anyMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'messageEpoch'),
      );
    });
  }
}

extension ChatGroupPendingCommitEntityQueryWhere on QueryBuilder<
    ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity, QWhereClause> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterWhereClause>
      ownerCidNumberNotEqualToAnyEnvelopeId(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterWhereClause>
      ownerCidNumberEnvelopeIdEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber_envelopeId',
        value: [ownerCidNumber, envelopeId],
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterWhereClause>
      ownerCidNumberEqualToEnvelopeIdNotEqualTo(
          String ownerCidNumber, String envelopeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber, envelopeId],
              includeLower: false,
              upper: [ownerCidNumber],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber_envelopeId',
              lower: [ownerCidNumber],
              upper: [ownerCidNumber, envelopeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupId',
        value: [groupId],
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> messageEpochEqualTo(int messageEpoch) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'messageEpoch',
        value: [messageEpoch],
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> messageEpochNotEqualTo(int messageEpoch) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageEpoch',
              lower: [],
              upper: [messageEpoch],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageEpoch',
              lower: [messageEpoch],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageEpoch',
              lower: [messageEpoch],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'messageEpoch',
              lower: [],
              upper: [messageEpoch],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> messageEpochGreaterThan(
    int messageEpoch, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageEpoch',
        lower: [messageEpoch],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> messageEpochLessThan(
    int messageEpoch, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageEpoch',
        lower: [],
        upper: [messageEpoch],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterWhereClause> messageEpochBetween(
    int lowerMessageEpoch,
    int upperMessageEpoch, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'messageEpoch',
        lower: [lowerMessageEpoch],
        includeLower: includeLower,
        upper: [upperMessageEpoch],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatGroupPendingCommitEntityQueryFilter on QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QFilterCondition> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> createdAtMillisGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> createdAtMillisLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtMillis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeBytesHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      envelopeBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeBytesHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      envelopeBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeBytesHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeBytesHex',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'envelopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      envelopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'envelopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      envelopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'envelopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> envelopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'envelopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> messageEpochEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageEpoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> messageEpochGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageEpoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> messageEpochLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageEpoch',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> messageEpochBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageEpoch',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }
}

extension ChatGroupPendingCommitEntityQueryObject on QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QFilterCondition> {}

extension ChatGroupPendingCommitEntityQueryLinks on QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QFilterCondition> {}

extension ChatGroupPendingCommitEntityQuerySortBy on QueryBuilder<
    ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity, QSortBy> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageEpoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByMessageEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageEpoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }
}

extension ChatGroupPendingCommitEntityQuerySortThenBy on QueryBuilder<
    ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity, QSortThenBy> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByEnvelopeBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByEnvelopeBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeBytesHex', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByEnvelopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByEnvelopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'envelopeId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageEpoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByMessageEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageEpoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QAfterSortBy> thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }
}

extension ChatGroupPendingCommitEntityQueryWhereDistinct on QueryBuilder<
    ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity, QDistinct> {
  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByEnvelopeBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeBytesHex',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByEnvelopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'envelopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageEpoch');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, ChatGroupPendingCommitEntity,
      QDistinct> distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChatGroupPendingCommitEntityQueryProperty on QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QQueryProperty> {
  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
      envelopeBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeBytesHex');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
      envelopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'envelopeId');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
      groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
      messageEpochProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageEpoch');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatAccountHandoverEntityCollection on Isar {
  IsarCollection<ChatAccountHandoverEntity> get chatAccountHandoverEntitys =>
      this.collection();
}

const ChatAccountHandoverEntitySchema = CollectionSchema(
  name: r'ChatAccountHandoverEntity',
  id: -8600758352353639666,
  properties: {
    r'handoverKey': PropertySchema(
      id: 0,
      name: r'handoverKey',
      type: IsarType.string,
    ),
    r'manifestJson': PropertySchema(
      id: 1,
      name: r'manifestJson',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 2,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'sourceAccountId': PropertySchema(
      id: 3,
      name: r'sourceAccountId',
      type: IsarType.string,
    ),
    r'sourceBindingRevision': PropertySchema(
      id: 4,
      name: r'sourceBindingRevision',
      type: IsarType.long,
    ),
    r'targetAccountId': PropertySchema(
      id: 5,
      name: r'targetAccountId',
      type: IsarType.string,
    ),
    r'targetBindingRevision': PropertySchema(
      id: 6,
      name: r'targetBindingRevision',
      type: IsarType.long,
    )
  },
  estimateSize: _chatAccountHandoverEntityEstimateSize,
  serialize: _chatAccountHandoverEntitySerialize,
  deserialize: _chatAccountHandoverEntityDeserialize,
  deserializeProp: _chatAccountHandoverEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'handoverKey': IndexSchema(
      id: 7996462905102947220,
      name: r'handoverKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'handoverKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'ownerCidNumber': IndexSchema(
      id: -7703291541778452577,
      name: r'ownerCidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatAccountHandoverEntityGetId,
  getLinks: _chatAccountHandoverEntityGetLinks,
  attach: _chatAccountHandoverEntityAttach,
  version: '3.3.2',
);

int _chatAccountHandoverEntityEstimateSize(
  ChatAccountHandoverEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.handoverKey.length * 3;
  bytesCount += 3 + object.manifestJson.length * 3;
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  bytesCount += 3 + object.sourceAccountId.length * 3;
  bytesCount += 3 + object.targetAccountId.length * 3;
  return bytesCount;
}

void _chatAccountHandoverEntitySerialize(
  ChatAccountHandoverEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.handoverKey);
  writer.writeString(offsets[1], object.manifestJson);
  writer.writeString(offsets[2], object.ownerCidNumber);
  writer.writeString(offsets[3], object.sourceAccountId);
  writer.writeLong(offsets[4], object.sourceBindingRevision);
  writer.writeString(offsets[5], object.targetAccountId);
  writer.writeLong(offsets[6], object.targetBindingRevision);
}

ChatAccountHandoverEntity _chatAccountHandoverEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatAccountHandoverEntity();
  object.handoverKey = reader.readString(offsets[0]);
  object.id = id;
  object.manifestJson = reader.readString(offsets[1]);
  object.ownerCidNumber = reader.readString(offsets[2]);
  object.sourceAccountId = reader.readString(offsets[3]);
  object.sourceBindingRevision = reader.readLong(offsets[4]);
  object.targetAccountId = reader.readString(offsets[5]);
  object.targetBindingRevision = reader.readLong(offsets[6]);
  return object;
}

P _chatAccountHandoverEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatAccountHandoverEntityGetId(ChatAccountHandoverEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatAccountHandoverEntityGetLinks(
    ChatAccountHandoverEntity object) {
  return [];
}

void _chatAccountHandoverEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatAccountHandoverEntity object) {
  object.id = id;
}

extension ChatAccountHandoverEntityByIndex
    on IsarCollection<ChatAccountHandoverEntity> {
  Future<ChatAccountHandoverEntity?> getByHandoverKey(String handoverKey) {
    return getByIndex(r'handoverKey', [handoverKey]);
  }

  ChatAccountHandoverEntity? getByHandoverKeySync(String handoverKey) {
    return getByIndexSync(r'handoverKey', [handoverKey]);
  }

  Future<bool> deleteByHandoverKey(String handoverKey) {
    return deleteByIndex(r'handoverKey', [handoverKey]);
  }

  bool deleteByHandoverKeySync(String handoverKey) {
    return deleteByIndexSync(r'handoverKey', [handoverKey]);
  }

  Future<List<ChatAccountHandoverEntity?>> getAllByHandoverKey(
      List<String> handoverKeyValues) {
    final values = handoverKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'handoverKey', values);
  }

  List<ChatAccountHandoverEntity?> getAllByHandoverKeySync(
      List<String> handoverKeyValues) {
    final values = handoverKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'handoverKey', values);
  }

  Future<int> deleteAllByHandoverKey(List<String> handoverKeyValues) {
    final values = handoverKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'handoverKey', values);
  }

  int deleteAllByHandoverKeySync(List<String> handoverKeyValues) {
    final values = handoverKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'handoverKey', values);
  }

  Future<Id> putByHandoverKey(ChatAccountHandoverEntity object) {
    return putByIndex(r'handoverKey', object);
  }

  Id putByHandoverKeySync(ChatAccountHandoverEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'handoverKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByHandoverKey(
      List<ChatAccountHandoverEntity> objects) {
    return putAllByIndex(r'handoverKey', objects);
  }

  List<Id> putAllByHandoverKeySync(List<ChatAccountHandoverEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'handoverKey', objects, saveLinks: saveLinks);
  }
}

extension ChatAccountHandoverEntityQueryWhereSort on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QWhere> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatAccountHandoverEntityQueryWhere on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QWhereClause> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> handoverKeyEqualTo(String handoverKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'handoverKey',
        value: [handoverKey],
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> handoverKeyNotEqualTo(String handoverKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'handoverKey',
              lower: [],
              upper: [handoverKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'handoverKey',
              lower: [handoverKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'handoverKey',
              lower: [handoverKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'handoverKey',
              lower: [],
              upper: [handoverKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> ownerCidNumberEqualTo(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterWhereClause> ownerCidNumberNotEqualTo(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatAccountHandoverEntityQueryFilter on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QFilterCondition> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'handoverKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      handoverKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'handoverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      handoverKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'handoverKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'handoverKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> handoverKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'handoverKey',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'manifestJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      manifestJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'manifestJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      manifestJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'manifestJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'manifestJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> manifestJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'manifestJson',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      sourceAccountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      sourceAccountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceBindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceBindingRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceBindingRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> sourceBindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceBindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      targetAccountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
          QAfterFilterCondition>
      targetAccountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetBindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetBindingRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetBindingRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterFilterCondition> targetBindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetBindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ChatAccountHandoverEntityQueryObject on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QFilterCondition> {}

extension ChatAccountHandoverEntityQueryLinks on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QFilterCondition> {}

extension ChatAccountHandoverEntityQuerySortBy on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QSortBy> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByHandoverKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'handoverKey', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByHandoverKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'handoverKey', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByManifestJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByManifestJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortBySourceAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortBySourceAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortBySourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortBySourceBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByTargetAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByTargetAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> sortByTargetBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetBindingRevision', Sort.desc);
    });
  }
}

extension ChatAccountHandoverEntityQuerySortThenBy on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QSortThenBy> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByHandoverKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'handoverKey', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByHandoverKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'handoverKey', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByManifestJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByManifestJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenBySourceAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenBySourceAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenBySourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenBySourceBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByTargetAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByTargetAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity,
      QAfterSortBy> thenByTargetBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetBindingRevision', Sort.desc);
    });
  }
}

extension ChatAccountHandoverEntityQueryWhereDistinct on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct> {
  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctByHandoverKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'handoverKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctByManifestJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'manifestJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctBySourceAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctBySourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceBindingRevision');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctByTargetAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, ChatAccountHandoverEntity, QDistinct>
      distinctByTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetBindingRevision');
    });
  }
}

extension ChatAccountHandoverEntityQueryProperty on QueryBuilder<
    ChatAccountHandoverEntity, ChatAccountHandoverEntity, QQueryProperty> {
  QueryBuilder<ChatAccountHandoverEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, String, QQueryOperations>
      handoverKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'handoverKey');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, String, QQueryOperations>
      manifestJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'manifestJson');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, String, QQueryOperations>
      sourceAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceAccountId');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, int, QQueryOperations>
      sourceBindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceBindingRevision');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, String, QQueryOperations>
      targetAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetAccountId');
    });
  }

  QueryBuilder<ChatAccountHandoverEntity, int, QQueryOperations>
      targetBindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetBindingRevision');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatBindingFenceEntityCollection on Isar {
  IsarCollection<ChatBindingFenceEntity> get chatBindingFenceEntitys =>
      this.collection();
}

const ChatBindingFenceEntitySchema = CollectionSchema(
  name: r'ChatBindingFenceEntity',
  id: -7632451107539516192,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'bindingRevision': PropertySchema(
      id: 1,
      name: r'bindingRevision',
      type: IsarType.long,
    ),
    r'completedGeneration': PropertySchema(
      id: 2,
      name: r'completedGeneration',
      type: IsarType.long,
    ),
    r'completedSourceAccountId': PropertySchema(
      id: 3,
      name: r'completedSourceAccountId',
      type: IsarType.string,
    ),
    r'completedSourceBindingRevision': PropertySchema(
      id: 4,
      name: r'completedSourceBindingRevision',
      type: IsarType.long,
    ),
    r'completedSourceGenesisHash': PropertySchema(
      id: 5,
      name: r'completedSourceGenesisHash',
      type: IsarType.string,
    ),
    r'completedTargetAccountId': PropertySchema(
      id: 6,
      name: r'completedTargetAccountId',
      type: IsarType.string,
    ),
    r'completedTargetBindingRevision': PropertySchema(
      id: 7,
      name: r'completedTargetBindingRevision',
      type: IsarType.long,
    ),
    r'completedTargetGenesisHash': PropertySchema(
      id: 8,
      name: r'completedTargetGenesisHash',
      type: IsarType.string,
    ),
    r'fenceState': PropertySchema(
      id: 9,
      name: r'fenceState',
      type: IsarType.string,
    ),
    r'generation': PropertySchema(
      id: 10,
      name: r'generation',
      type: IsarType.long,
    ),
    r'genesisHash': PropertySchema(
      id: 11,
      name: r'genesisHash',
      type: IsarType.string,
    ),
    r'ownerCidNumber': PropertySchema(
      id: 12,
      name: r'ownerCidNumber',
      type: IsarType.string,
    ),
    r'pendingAccountId': PropertySchema(
      id: 13,
      name: r'pendingAccountId',
      type: IsarType.string,
    ),
    r'pendingBindingRevision': PropertySchema(
      id: 14,
      name: r'pendingBindingRevision',
      type: IsarType.long,
    ),
    r'pendingGenesisHash': PropertySchema(
      id: 15,
      name: r'pendingGenesisHash',
      type: IsarType.string,
    )
  },
  estimateSize: _chatBindingFenceEntityEstimateSize,
  serialize: _chatBindingFenceEntitySerialize,
  deserialize: _chatBindingFenceEntityDeserialize,
  deserializeProp: _chatBindingFenceEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'ownerCidNumber': IndexSchema(
      id: -7703291541778452577,
      name: r'ownerCidNumber',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerCidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _chatBindingFenceEntityGetId,
  getLinks: _chatBindingFenceEntityGetLinks,
  attach: _chatBindingFenceEntityAttach,
  version: '3.3.2',
);

int _chatBindingFenceEntityEstimateSize(
  ChatBindingFenceEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.accountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedSourceAccountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedSourceGenesisHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedTargetAccountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedTargetGenesisHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.fenceState.length * 3;
  {
    final value = object.genesisHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerCidNumber.length * 3;
  {
    final value = object.pendingAccountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.pendingGenesisHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chatBindingFenceEntitySerialize(
  ChatBindingFenceEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeLong(offsets[2], object.completedGeneration);
  writer.writeString(offsets[3], object.completedSourceAccountId);
  writer.writeLong(offsets[4], object.completedSourceBindingRevision);
  writer.writeString(offsets[5], object.completedSourceGenesisHash);
  writer.writeString(offsets[6], object.completedTargetAccountId);
  writer.writeLong(offsets[7], object.completedTargetBindingRevision);
  writer.writeString(offsets[8], object.completedTargetGenesisHash);
  writer.writeString(offsets[9], object.fenceState);
  writer.writeLong(offsets[10], object.generation);
  writer.writeString(offsets[11], object.genesisHash);
  writer.writeString(offsets[12], object.ownerCidNumber);
  writer.writeString(offsets[13], object.pendingAccountId);
  writer.writeLong(offsets[14], object.pendingBindingRevision);
  writer.writeString(offsets[15], object.pendingGenesisHash);
}

ChatBindingFenceEntity _chatBindingFenceEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatBindingFenceEntity();
  object.accountId = reader.readStringOrNull(offsets[0]);
  object.bindingRevision = reader.readLongOrNull(offsets[1]);
  object.completedGeneration = reader.readLongOrNull(offsets[2]);
  object.completedSourceAccountId = reader.readStringOrNull(offsets[3]);
  object.completedSourceBindingRevision = reader.readLongOrNull(offsets[4]);
  object.completedSourceGenesisHash = reader.readStringOrNull(offsets[5]);
  object.completedTargetAccountId = reader.readStringOrNull(offsets[6]);
  object.completedTargetBindingRevision = reader.readLongOrNull(offsets[7]);
  object.completedTargetGenesisHash = reader.readStringOrNull(offsets[8]);
  object.fenceState = reader.readString(offsets[9]);
  object.generation = reader.readLong(offsets[10]);
  object.genesisHash = reader.readStringOrNull(offsets[11]);
  object.id = id;
  object.ownerCidNumber = reader.readString(offsets[12]);
  object.pendingAccountId = reader.readStringOrNull(offsets[13]);
  object.pendingBindingRevision = reader.readLongOrNull(offsets[14]);
  object.pendingGenesisHash = reader.readStringOrNull(offsets[15]);
  return object;
}

P _chatBindingFenceEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatBindingFenceEntityGetId(ChatBindingFenceEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatBindingFenceEntityGetLinks(
    ChatBindingFenceEntity object) {
  return [];
}

void _chatBindingFenceEntityAttach(
    IsarCollection<dynamic> col, Id id, ChatBindingFenceEntity object) {
  object.id = id;
}

extension ChatBindingFenceEntityByIndex
    on IsarCollection<ChatBindingFenceEntity> {
  Future<ChatBindingFenceEntity?> getByOwnerCidNumber(String ownerCidNumber) {
    return getByIndex(r'ownerCidNumber', [ownerCidNumber]);
  }

  ChatBindingFenceEntity? getByOwnerCidNumberSync(String ownerCidNumber) {
    return getByIndexSync(r'ownerCidNumber', [ownerCidNumber]);
  }

  Future<bool> deleteByOwnerCidNumber(String ownerCidNumber) {
    return deleteByIndex(r'ownerCidNumber', [ownerCidNumber]);
  }

  bool deleteByOwnerCidNumberSync(String ownerCidNumber) {
    return deleteByIndexSync(r'ownerCidNumber', [ownerCidNumber]);
  }

  Future<List<ChatBindingFenceEntity?>> getAllByOwnerCidNumber(
      List<String> ownerCidNumberValues) {
    final values = ownerCidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'ownerCidNumber', values);
  }

  List<ChatBindingFenceEntity?> getAllByOwnerCidNumberSync(
      List<String> ownerCidNumberValues) {
    final values = ownerCidNumberValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'ownerCidNumber', values);
  }

  Future<int> deleteAllByOwnerCidNumber(List<String> ownerCidNumberValues) {
    final values = ownerCidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'ownerCidNumber', values);
  }

  int deleteAllByOwnerCidNumberSync(List<String> ownerCidNumberValues) {
    final values = ownerCidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'ownerCidNumber', values);
  }

  Future<Id> putByOwnerCidNumber(ChatBindingFenceEntity object) {
    return putByIndex(r'ownerCidNumber', object);
  }

  Id putByOwnerCidNumberSync(ChatBindingFenceEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'ownerCidNumber', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerCidNumber(
      List<ChatBindingFenceEntity> objects) {
    return putAllByIndex(r'ownerCidNumber', objects);
  }

  List<Id> putAllByOwnerCidNumberSync(List<ChatBindingFenceEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'ownerCidNumber', objects, saveLinks: saveLinks);
  }
}

extension ChatBindingFenceEntityQueryWhereSort
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QWhere> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatBindingFenceEntityQueryWhere on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QWhereClause> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> ownerCidNumberEqualTo(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerCidNumber',
        value: [ownerCidNumber],
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterWhereClause> ownerCidNumberNotEqualTo(String ownerCidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [ownerCidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerCidNumber',
              lower: [],
              upper: [ownerCidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ChatBindingFenceEntityQueryFilter on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QFilterCondition> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'accountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'accountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'accountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'accountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'bindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'bindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> bindingRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedGeneration',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedGeneration',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedGenerationBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedGeneration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedSourceAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedSourceAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedSourceAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedSourceAccountIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedSourceAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedSourceAccountIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedSourceAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedSourceAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedSourceAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedSourceBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedSourceBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedSourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedSourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedSourceBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceBindingRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedSourceBindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedSourceGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedSourceGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedSourceGenesisHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedSourceGenesisHashContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedSourceGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedSourceGenesisHashMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedSourceGenesisHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedSourceGenesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedSourceGenesisHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedSourceGenesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedTargetAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedTargetAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedTargetAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedTargetAccountIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedTargetAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedTargetAccountIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedTargetAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedTargetAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedTargetAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedTargetBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedTargetBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedTargetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedTargetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedTargetBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetBindingRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedTargetBindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedTargetGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedTargetGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedTargetGenesisHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedTargetGenesisHashContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedTargetGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      completedTargetGenesisHashMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedTargetGenesisHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedTargetGenesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> completedTargetGenesisHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedTargetGenesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fenceState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      fenceStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fenceState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      fenceStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fenceState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fenceState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> fenceStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fenceState',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> generationEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'generation',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> generationGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'generation',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> generationLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'generation',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> generationBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'generation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'genesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'genesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'genesisHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      genesisHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'genesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      genesisHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'genesisHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'genesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> genesisHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'genesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      ownerCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      ownerCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> ownerCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pendingAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pendingAccountId',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pendingAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      pendingAccountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pendingAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      pendingAccountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pendingAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pendingAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pendingBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pendingBindingRevision',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pendingBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pendingBindingRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingBindingRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pendingBindingRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pendingGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pendingGenesisHash',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pendingGenesisHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      pendingGenesisHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pendingGenesisHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
          QAfterFilterCondition>
      pendingGenesisHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pendingGenesisHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingGenesisHash',
        value: '',
      ));
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity,
      QAfterFilterCondition> pendingGenesisHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pendingGenesisHash',
        value: '',
      ));
    });
  }
}

extension ChatBindingFenceEntityQueryObject on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QFilterCondition> {}

extension ChatBindingFenceEntityQueryLinks on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QFilterCondition> {}

extension ChatBindingFenceEntityQuerySortBy
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QSortBy> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedGeneration', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedGeneration', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedSourceGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceGenesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByCompletedTargetGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetGenesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByFenceState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fenceState', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByFenceStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fenceState', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generation', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generation', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      sortByPendingGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingGenesisHash', Sort.desc);
    });
  }
}

extension ChatBindingFenceEntityQuerySortThenBy on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QSortThenBy> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedGeneration', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedGeneration', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedSourceGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedSourceGenesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByCompletedTargetGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedTargetGenesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByFenceState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fenceState', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByFenceStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fenceState', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generation', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'generation', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genesisHash', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByOwnerCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByOwnerCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerCidNumber', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingAccountId', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingAccountId', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBindingRevision', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingBindingRevision', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingGenesisHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingGenesisHash', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
      thenByPendingGenesisHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingGenesisHash', Sort.desc);
    });
  }
}

extension ChatBindingFenceEntityQueryWhereDistinct
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedGeneration');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedSourceAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedSourceAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedSourceBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedSourceBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedSourceGenesisHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedSourceGenesisHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedTargetAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedTargetAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedTargetBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedTargetBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByCompletedTargetGenesisHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedTargetGenesisHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByFenceState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fenceState', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'generation');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByGenesisHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genesisHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByOwnerCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByPendingAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByPendingBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
      distinctByPendingGenesisHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingGenesisHash',
          caseSensitive: caseSensitive);
    });
  }
}

extension ChatBindingFenceEntityQueryProperty on QueryBuilder<
    ChatBindingFenceEntity, ChatBindingFenceEntity, QQueryProperty> {
  QueryBuilder<ChatBindingFenceEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
      bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
      completedGenerationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedGeneration');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      completedSourceAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedSourceAccountId');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
      completedSourceBindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedSourceBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      completedSourceGenesisHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedSourceGenesisHash');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      completedTargetAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedTargetAccountId');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
      completedTargetBindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedTargetBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      completedTargetGenesisHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedTargetGenesisHash');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String, QQueryOperations>
      fenceStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fenceState');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int, QQueryOperations>
      generationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'generation');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      genesisHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genesisHash');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String, QQueryOperations>
      ownerCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerCidNumber');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      pendingAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingAccountId');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
      pendingBindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingBindingRevision');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
      pendingGenesisHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingGenesisHash');
    });
  }
}
