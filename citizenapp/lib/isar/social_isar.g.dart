// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSquareLocalPostEntityCollection on Isar {
  IsarCollection<SquareLocalPostEntity> get squareLocalPostEntitys =>
      this.collection();
}

const SquareLocalPostEntitySchema = CollectionSchema(
  name: r'SquareLocalPostEntity',
  id: 3392182366809581442,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'chainBlock': PropertySchema(
      id: 1,
      name: r'chainBlock',
      type: IsarType.long,
    ),
    r'cidNumber': PropertySchema(
      id: 2,
      name: r'cidNumber',
      type: IsarType.string,
    ),
    r'contentHash': PropertySchema(
      id: 3,
      name: r'contentHash',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 4,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'manifestBytes': PropertySchema(
      id: 5,
      name: r'manifestBytes',
      type: IsarType.byteList,
    ),
    r'postCategory': PropertySchema(
      id: 6,
      name: r'postCategory',
      type: IsarType.string,
    ),
    r'postId': PropertySchema(
      id: 7,
      name: r'postId',
      type: IsarType.string,
    ),
    r'postState': PropertySchema(
      id: 8,
      name: r'postState',
      type: IsarType.string,
    ),
    r'postType': PropertySchema(
      id: 9,
      name: r'postType',
      type: IsarType.string,
    ),
    r'storageReceiptId': PropertySchema(
      id: 10,
      name: r'storageReceiptId',
      type: IsarType.string,
    )
  },
  estimateSize: _squareLocalPostEntityEstimateSize,
  serialize: _squareLocalPostEntitySerialize,
  deserialize: _squareLocalPostEntityDeserialize,
  deserializeProp: _squareLocalPostEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'postId': IndexSchema(
      id: -544810920068516617,
      name: r'postId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'postId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'cidNumber': IndexSchema(
      id: -8947736671869741624,
      name: r'cidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _squareLocalPostEntityGetId,
  getLinks: _squareLocalPostEntityGetLinks,
  attach: _squareLocalPostEntityAttach,
  version: '3.3.2',
);

int _squareLocalPostEntityEstimateSize(
  SquareLocalPostEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.contentHash.length * 3;
  bytesCount += 3 + object.manifestBytes.length;
  bytesCount += 3 + object.postCategory.length * 3;
  bytesCount += 3 + object.postId.length * 3;
  bytesCount += 3 + object.postState.length * 3;
  bytesCount += 3 + object.postType.length * 3;
  bytesCount += 3 + object.storageReceiptId.length * 3;
  return bytesCount;
}

void _squareLocalPostEntitySerialize(
  SquareLocalPostEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.chainBlock);
  writer.writeString(offsets[2], object.cidNumber);
  writer.writeString(offsets[3], object.contentHash);
  writer.writeLong(offsets[4], object.createdAt);
  writer.writeByteList(offsets[5], object.manifestBytes);
  writer.writeString(offsets[6], object.postCategory);
  writer.writeString(offsets[7], object.postId);
  writer.writeString(offsets[8], object.postState);
  writer.writeString(offsets[9], object.postType);
  writer.writeString(offsets[10], object.storageReceiptId);
}

SquareLocalPostEntity _squareLocalPostEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SquareLocalPostEntity();
  object.accountId = reader.readString(offsets[0]);
  object.chainBlock = reader.readLongOrNull(offsets[1]);
  object.cidNumber = reader.readString(offsets[2]);
  object.contentHash = reader.readString(offsets[3]);
  object.createdAt = reader.readLong(offsets[4]);
  object.id = id;
  object.manifestBytes = reader.readByteList(offsets[5]) ?? [];
  object.postCategory = reader.readString(offsets[6]);
  object.postId = reader.readString(offsets[7]);
  object.postState = reader.readString(offsets[8]);
  object.postType = reader.readString(offsets[9]);
  object.storageReceiptId = reader.readString(offsets[10]);
  return object;
}

P _squareLocalPostEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readByteList(offset) ?? []) as P;
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _squareLocalPostEntityGetId(SquareLocalPostEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _squareLocalPostEntityGetLinks(
    SquareLocalPostEntity object) {
  return [];
}

void _squareLocalPostEntityAttach(
    IsarCollection<dynamic> col, Id id, SquareLocalPostEntity object) {
  object.id = id;
}

extension SquareLocalPostEntityByIndex
    on IsarCollection<SquareLocalPostEntity> {
  Future<SquareLocalPostEntity?> getByPostId(String postId) {
    return getByIndex(r'postId', [postId]);
  }

  SquareLocalPostEntity? getByPostIdSync(String postId) {
    return getByIndexSync(r'postId', [postId]);
  }

  Future<bool> deleteByPostId(String postId) {
    return deleteByIndex(r'postId', [postId]);
  }

  bool deleteByPostIdSync(String postId) {
    return deleteByIndexSync(r'postId', [postId]);
  }

  Future<List<SquareLocalPostEntity?>> getAllByPostId(
      List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'postId', values);
  }

  List<SquareLocalPostEntity?> getAllByPostIdSync(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'postId', values);
  }

  Future<int> deleteAllByPostId(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'postId', values);
  }

  int deleteAllByPostIdSync(List<String> postIdValues) {
    final values = postIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'postId', values);
  }

  Future<Id> putByPostId(SquareLocalPostEntity object) {
    return putByIndex(r'postId', object);
  }

  Id putByPostIdSync(SquareLocalPostEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'postId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPostId(List<SquareLocalPostEntity> objects) {
    return putAllByIndex(r'postId', objects);
  }

  List<Id> putAllByPostIdSync(List<SquareLocalPostEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'postId', objects, saveLinks: saveLinks);
  }
}

extension SquareLocalPostEntityQueryWhereSort
    on QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QWhere> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension SquareLocalPostEntityQueryWhere on QueryBuilder<SquareLocalPostEntity,
    SquareLocalPostEntity, QWhereClause> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      postIdEqualTo(String postId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'postId',
        value: [postId],
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      postIdNotEqualTo(String postId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'postId',
              lower: [],
              upper: [postId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'postId',
              lower: [postId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'postId',
              lower: [postId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'postId',
              lower: [],
              upper: [postId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      cidNumberEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cidNumber',
        value: [cidNumber],
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      cidNumberNotEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      createdAtEqualTo(int createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      createdAtNotEqualTo(int createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      createdAtGreaterThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      createdAtLessThan(
    int createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterWhereClause>
      createdAtBetween(
    int lowerCreatedAt,
    int upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SquareLocalPostEntityQueryFilter on QueryBuilder<
    SquareLocalPostEntity, SquareLocalPostEntity, QFilterCondition> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'accountId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chainBlock',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chainBlock',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chainBlock',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chainBlock',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chainBlock',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> chainBlockBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chainBlock',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      cidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      cidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      contentHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      contentHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> contentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
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

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'manifestBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'manifestBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'manifestBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'manifestBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> manifestBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'manifestBytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postCategory',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postCategoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'postCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postCategoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'postCategory',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'postCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'postId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'postId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'postId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'postState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'postState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postState',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'postState',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      postTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'postType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postType',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> postTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'postType',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storageReceiptId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      storageReceiptIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storageReceiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
          QAfterFilterCondition>
      storageReceiptIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storageReceiptId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storageReceiptId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity,
      QAfterFilterCondition> storageReceiptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storageReceiptId',
        value: '',
      ));
    });
  }
}

extension SquareLocalPostEntityQueryObject on QueryBuilder<
    SquareLocalPostEntity, SquareLocalPostEntity, QFilterCondition> {}

extension SquareLocalPostEntityQueryLinks on QueryBuilder<SquareLocalPostEntity,
    SquareLocalPostEntity, QFilterCondition> {}

extension SquareLocalPostEntityQuerySortBy
    on QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QSortBy> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chainBlock', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chainBlock', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postCategory', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postCategory', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postId', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postState', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postState', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByStorageReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageReceiptId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      sortByStorageReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageReceiptId', Sort.desc);
    });
  }
}

extension SquareLocalPostEntityQuerySortThenBy
    on QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QSortThenBy> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chainBlock', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByChainBlockDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chainBlock', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postCategory', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postCategory', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postId', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postState', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postState', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.desc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByStorageReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageReceiptId', Sort.asc);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QAfterSortBy>
      thenByStorageReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storageReceiptId', Sort.desc);
    });
  }
}

extension SquareLocalPostEntityQueryWhereDistinct
    on QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct> {
  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByChainBlock() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chainBlock');
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByContentHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByManifestBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'manifestBytes');
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByPostCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postCategory', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByPostId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByPostState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postState', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByPostType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareLocalPostEntity, SquareLocalPostEntity, QDistinct>
      distinctByStorageReceiptId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storageReceiptId',
          caseSensitive: caseSensitive);
    });
  }
}

extension SquareLocalPostEntityQueryProperty on QueryBuilder<
    SquareLocalPostEntity, SquareLocalPostEntity, QQueryProperty> {
  QueryBuilder<SquareLocalPostEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<SquareLocalPostEntity, int?, QQueryOperations>
      chainBlockProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chainBlock');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidNumber');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      contentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentHash');
    });
  }

  QueryBuilder<SquareLocalPostEntity, int, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SquareLocalPostEntity, List<int>, QQueryOperations>
      manifestBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'manifestBytes');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      postCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postCategory');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      postIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postId');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      postStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postState');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      postTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postType');
    });
  }

  QueryBuilder<SquareLocalPostEntity, String, QQueryOperations>
      storageReceiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storageReceiptId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSquareComposeDraftEntityCollection on Isar {
  IsarCollection<SquareComposeDraftEntity> get squareComposeDraftEntitys =>
      this.collection();
}

const SquareComposeDraftEntitySchema = CollectionSchema(
  name: r'SquareComposeDraftEntity',
  id: 6833934357716734959,
  properties: {
    r'cidNumber': PropertySchema(
      id: 0,
      name: r'cidNumber',
      type: IsarType.string,
    ),
    r'contentSectionsJson': PropertySchema(
      id: 1,
      name: r'contentSectionsJson',
      type: IsarType.string,
    ),
    r'draftId': PropertySchema(
      id: 2,
      name: r'draftId',
      type: IsarType.string,
    ),
    r'draftKey': PropertySchema(
      id: 3,
      name: r'draftKey',
      type: IsarType.string,
    ),
    r'mediaJson': PropertySchema(
      id: 4,
      name: r'mediaJson',
      type: IsarType.string,
    ),
    r'postType': PropertySchema(
      id: 5,
      name: r'postType',
      type: IsarType.string,
    ),
    r'text': PropertySchema(
      id: 6,
      name: r'text',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 7,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 8,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _squareComposeDraftEntityEstimateSize,
  serialize: _squareComposeDraftEntitySerialize,
  deserialize: _squareComposeDraftEntityDeserialize,
  deserializeProp: _squareComposeDraftEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'draftKey': IndexSchema(
      id: -6531847789214907499,
      name: r'draftKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'draftKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'cidNumber': IndexSchema(
      id: -8947736671869741624,
      name: r'cidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cidNumber',
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
  getId: _squareComposeDraftEntityGetId,
  getLinks: _squareComposeDraftEntityGetLinks,
  attach: _squareComposeDraftEntityAttach,
  version: '3.3.2',
);

int _squareComposeDraftEntityEstimateSize(
  SquareComposeDraftEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.contentSectionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.draftId.length * 3;
  bytesCount += 3 + object.draftKey.length * 3;
  bytesCount += 3 + object.mediaJson.length * 3;
  bytesCount += 3 + object.postType.length * 3;
  bytesCount += 3 + object.text.length * 3;
  {
    final value = object.title;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _squareComposeDraftEntitySerialize(
  SquareComposeDraftEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeString(offsets[1], object.contentSectionsJson);
  writer.writeString(offsets[2], object.draftId);
  writer.writeString(offsets[3], object.draftKey);
  writer.writeString(offsets[4], object.mediaJson);
  writer.writeString(offsets[5], object.postType);
  writer.writeString(offsets[6], object.text);
  writer.writeString(offsets[7], object.title);
  writer.writeLong(offsets[8], object.updatedAtMillis);
}

SquareComposeDraftEntity _squareComposeDraftEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SquareComposeDraftEntity();
  object.cidNumber = reader.readString(offsets[0]);
  object.contentSectionsJson = reader.readStringOrNull(offsets[1]);
  object.draftId = reader.readString(offsets[2]);
  object.draftKey = reader.readString(offsets[3]);
  object.id = id;
  object.mediaJson = reader.readString(offsets[4]);
  object.postType = reader.readString(offsets[5]);
  object.text = reader.readString(offsets[6]);
  object.title = reader.readStringOrNull(offsets[7]);
  object.updatedAtMillis = reader.readLong(offsets[8]);
  return object;
}

P _squareComposeDraftEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _squareComposeDraftEntityGetId(SquareComposeDraftEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _squareComposeDraftEntityGetLinks(
    SquareComposeDraftEntity object) {
  return [];
}

void _squareComposeDraftEntityAttach(
    IsarCollection<dynamic> col, Id id, SquareComposeDraftEntity object) {
  object.id = id;
}

extension SquareComposeDraftEntityByIndex
    on IsarCollection<SquareComposeDraftEntity> {
  Future<SquareComposeDraftEntity?> getByDraftKey(String draftKey) {
    return getByIndex(r'draftKey', [draftKey]);
  }

  SquareComposeDraftEntity? getByDraftKeySync(String draftKey) {
    return getByIndexSync(r'draftKey', [draftKey]);
  }

  Future<bool> deleteByDraftKey(String draftKey) {
    return deleteByIndex(r'draftKey', [draftKey]);
  }

  bool deleteByDraftKeySync(String draftKey) {
    return deleteByIndexSync(r'draftKey', [draftKey]);
  }

  Future<List<SquareComposeDraftEntity?>> getAllByDraftKey(
      List<String> draftKeyValues) {
    final values = draftKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'draftKey', values);
  }

  List<SquareComposeDraftEntity?> getAllByDraftKeySync(
      List<String> draftKeyValues) {
    final values = draftKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'draftKey', values);
  }

  Future<int> deleteAllByDraftKey(List<String> draftKeyValues) {
    final values = draftKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'draftKey', values);
  }

  int deleteAllByDraftKeySync(List<String> draftKeyValues) {
    final values = draftKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'draftKey', values);
  }

  Future<Id> putByDraftKey(SquareComposeDraftEntity object) {
    return putByIndex(r'draftKey', object);
  }

  Id putByDraftKeySync(SquareComposeDraftEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'draftKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDraftKey(List<SquareComposeDraftEntity> objects) {
    return putAllByIndex(r'draftKey', objects);
  }

  List<Id> putAllByDraftKeySync(List<SquareComposeDraftEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'draftKey', objects, saveLinks: saveLinks);
  }
}

extension SquareComposeDraftEntityQueryWhereSort on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QWhere> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterWhere>
      anyUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAtMillis'),
      );
    });
  }
}

extension SquareComposeDraftEntityQueryWhere on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QWhereClause> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> draftKeyEqualTo(String draftKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'draftKey',
        value: [draftKey],
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> draftKeyNotEqualTo(String draftKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'draftKey',
              lower: [],
              upper: [draftKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'draftKey',
              lower: [draftKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'draftKey',
              lower: [draftKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'draftKey',
              lower: [],
              upper: [draftKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> cidNumberEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cidNumber',
        value: [cidNumber],
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> cidNumberNotEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterWhereClause> updatedAtMillisEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAtMillis',
        value: [updatedAtMillis],
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

extension SquareComposeDraftEntityQueryFilter on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QFilterCondition> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      cidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      cidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'contentSectionsJson',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'contentSectionsJson',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentSectionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      contentSectionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentSectionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      contentSectionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentSectionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentSectionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> contentSectionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentSectionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'draftId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      draftIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      draftIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'draftId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'draftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'draftKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      draftKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'draftKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      draftKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'draftKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> draftKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'draftKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      mediaJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      mediaJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> mediaJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      postTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'postType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      postTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'postType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postType',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> postTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'postType',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'text',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      textContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
          QAfterFilterCondition>
      textMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'title',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'title',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleEqualTo(
    String? value, {
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleGreaterThan(
    String? value, {
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleLessThan(
    String? value, {
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity,
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

extension SquareComposeDraftEntityQueryObject on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QFilterCondition> {}

extension SquareComposeDraftEntityQueryLinks on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QFilterCondition> {}

extension SquareComposeDraftEntityQuerySortBy on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QSortBy> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByContentSectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByContentSectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSectionsJson', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByDraftKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftKey', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByDraftKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftKey', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByMediaJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaJson', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByMediaJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaJson', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension SquareComposeDraftEntityQuerySortThenBy on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QSortThenBy> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByContentSectionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSectionsJson', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByContentSectionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentSectionsJson', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByDraftKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftKey', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByDraftKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftKey', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByMediaJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaJson', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByMediaJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaJson', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByPostType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByPostTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postType', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension SquareComposeDraftEntityQueryWhereDistinct on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct> {
  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByContentSectionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentSectionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByDraftId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draftId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByDraftKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draftKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByMediaJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByPostType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'text', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareComposeDraftEntity, SquareComposeDraftEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension SquareComposeDraftEntityQueryProperty on QueryBuilder<
    SquareComposeDraftEntity, SquareComposeDraftEntity, QQueryProperty> {
  QueryBuilder<SquareComposeDraftEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidNumber');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String?, QQueryOperations>
      contentSectionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentSectionsJson');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      draftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draftId');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      draftKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draftKey');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      mediaJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaJson');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      postTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postType');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String, QQueryOperations>
      textProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'text');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, String?, QQueryOperations>
      titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<SquareComposeDraftEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSquarePostSyncCheckpointEntityCollection on Isar {
  IsarCollection<SquarePostSyncCheckpointEntity>
      get squarePostSyncCheckpointEntitys => this.collection();
}

const SquarePostSyncCheckpointEntitySchema = CollectionSchema(
  name: r'SquarePostSyncCheckpointEntity',
  id: -8272134114827660795,
  properties: {
    r'cidNumber': PropertySchema(
      id: 0,
      name: r'cidNumber',
      type: IsarType.string,
    ),
    r'newestCreatedAt': PropertySchema(
      id: 1,
      name: r'newestCreatedAt',
      type: IsarType.long,
    ),
    r'newestPostId': PropertySchema(
      id: 2,
      name: r'newestPostId',
      type: IsarType.string,
    )
  },
  estimateSize: _squarePostSyncCheckpointEntityEstimateSize,
  serialize: _squarePostSyncCheckpointEntitySerialize,
  deserialize: _squarePostSyncCheckpointEntityDeserialize,
  deserializeProp: _squarePostSyncCheckpointEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'cidNumber': IndexSchema(
      id: -8947736671869741624,
      name: r'cidNumber',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _squarePostSyncCheckpointEntityGetId,
  getLinks: _squarePostSyncCheckpointEntityGetLinks,
  attach: _squarePostSyncCheckpointEntityAttach,
  version: '3.3.2',
);

int _squarePostSyncCheckpointEntityEstimateSize(
  SquarePostSyncCheckpointEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.newestPostId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _squarePostSyncCheckpointEntitySerialize(
  SquarePostSyncCheckpointEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cidNumber);
  writer.writeLong(offsets[1], object.newestCreatedAt);
  writer.writeString(offsets[2], object.newestPostId);
}

SquarePostSyncCheckpointEntity _squarePostSyncCheckpointEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SquarePostSyncCheckpointEntity();
  object.cidNumber = reader.readString(offsets[0]);
  object.id = id;
  object.newestCreatedAt = reader.readLong(offsets[1]);
  object.newestPostId = reader.readStringOrNull(offsets[2]);
  return object;
}

P _squarePostSyncCheckpointEntityDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _squarePostSyncCheckpointEntityGetId(SquarePostSyncCheckpointEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _squarePostSyncCheckpointEntityGetLinks(
    SquarePostSyncCheckpointEntity object) {
  return [];
}

void _squarePostSyncCheckpointEntityAttach(
    IsarCollection<dynamic> col, Id id, SquarePostSyncCheckpointEntity object) {
  object.id = id;
}

extension SquarePostSyncCheckpointEntityByIndex
    on IsarCollection<SquarePostSyncCheckpointEntity> {
  Future<SquarePostSyncCheckpointEntity?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cidNumber', [cidNumber]);
  }

  SquarePostSyncCheckpointEntity? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cidNumber', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cidNumber', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cidNumber', [cidNumber]);
  }

  Future<List<SquarePostSyncCheckpointEntity?>> getAllByCidNumber(
      List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cidNumber', values);
  }

  List<SquarePostSyncCheckpointEntity?> getAllByCidNumberSync(
      List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'cidNumber', values);
  }

  Future<int> deleteAllByCidNumber(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'cidNumber', values);
  }

  int deleteAllByCidNumberSync(List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'cidNumber', values);
  }

  Future<Id> putByCidNumber(SquarePostSyncCheckpointEntity object) {
    return putByIndex(r'cidNumber', object);
  }

  Id putByCidNumberSync(SquarePostSyncCheckpointEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'cidNumber', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(
      List<SquarePostSyncCheckpointEntity> objects) {
    return putAllByIndex(r'cidNumber', objects);
  }

  List<Id> putAllByCidNumberSync(List<SquarePostSyncCheckpointEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'cidNumber', objects, saveLinks: saveLinks);
  }
}

extension SquarePostSyncCheckpointEntityQueryWhereSort on QueryBuilder<
    SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity, QWhere> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SquarePostSyncCheckpointEntityQueryWhere on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QWhereClause> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
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

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
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

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhereClause> cidNumberEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cidNumber',
        value: [cidNumber],
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterWhereClause> cidNumberNotEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SquarePostSyncCheckpointEntityQueryFilter on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QFilterCondition> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
          QAfterFilterCondition>
      cidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
          QAfterFilterCondition>
      cidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
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

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
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

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
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

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestCreatedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newestCreatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestCreatedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'newestCreatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestCreatedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'newestCreatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestCreatedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'newestCreatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'newestPostId',
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'newestPostId',
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'newestPostId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
          QAfterFilterCondition>
      newestPostIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'newestPostId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
          QAfterFilterCondition>
      newestPostIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'newestPostId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newestPostId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterFilterCondition> newestPostIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'newestPostId',
        value: '',
      ));
    });
  }
}

extension SquarePostSyncCheckpointEntityQueryObject on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QFilterCondition> {}

extension SquarePostSyncCheckpointEntityQueryLinks on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QFilterCondition> {}

extension SquarePostSyncCheckpointEntityQuerySortBy on QueryBuilder<
    SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity, QSortBy> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByNewestCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestCreatedAt', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByNewestCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestCreatedAt', Sort.desc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByNewestPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestPostId', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> sortByNewestPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestPostId', Sort.desc);
    });
  }
}

extension SquarePostSyncCheckpointEntityQuerySortThenBy on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QSortThenBy> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByNewestCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestCreatedAt', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByNewestCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestCreatedAt', Sort.desc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByNewestPostId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestPostId', Sort.asc);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QAfterSortBy> thenByNewestPostIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newestPostId', Sort.desc);
    });
  }
}

extension SquarePostSyncCheckpointEntityQueryWhereDistinct on QueryBuilder<
    SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity, QDistinct> {
  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QDistinct> distinctByCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QDistinct> distinctByNewestCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newestCreatedAt');
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, SquarePostSyncCheckpointEntity,
      QDistinct> distinctByNewestPostId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newestPostId', caseSensitive: caseSensitive);
    });
  }
}

extension SquarePostSyncCheckpointEntityQueryProperty on QueryBuilder<
    SquarePostSyncCheckpointEntity,
    SquarePostSyncCheckpointEntity,
    QQueryProperty> {
  QueryBuilder<SquarePostSyncCheckpointEntity, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, String, QQueryOperations>
      cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidNumber');
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, int, QQueryOperations>
      newestCreatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newestCreatedAt');
    });
  }

  QueryBuilder<SquarePostSyncCheckpointEntity, String?, QQueryOperations>
      newestPostIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newestPostId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSquareFileCleanupEntityCollection on Isar {
  IsarCollection<SquareFileCleanupEntity> get squareFileCleanupEntitys =>
      this.collection();
}

const SquareFileCleanupEntitySchema = CollectionSchema(
  name: r'SquareFileCleanupEntity',
  id: -7588075730518139899,
  properties: {
    r'attemptCount': PropertySchema(
      id: 0,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'cidNumber': PropertySchema(
      id: 1,
      name: r'cidNumber',
      type: IsarType.string,
    ),
    r'cleanupKey': PropertySchema(
      id: 2,
      name: r'cleanupKey',
      type: IsarType.string,
    ),
    r'cleanupKind': PropertySchema(
      id: 3,
      name: r'cleanupKind',
      type: IsarType.string,
    ),
    r'createdAtMillis': PropertySchema(
      id: 4,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'draftId': PropertySchema(
      id: 5,
      name: r'draftId',
      type: IsarType.string,
    ),
    r'lastError': PropertySchema(
      id: 6,
      name: r'lastError',
      type: IsarType.string,
    )
  },
  estimateSize: _squareFileCleanupEntityEstimateSize,
  serialize: _squareFileCleanupEntitySerialize,
  deserialize: _squareFileCleanupEntityDeserialize,
  deserializeProp: _squareFileCleanupEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'cleanupKey': IndexSchema(
      id: 58416111559704027,
      name: r'cleanupKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'cleanupKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'cidNumber': IndexSchema(
      id: -8947736671869741624,
      name: r'cidNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cidNumber',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _squareFileCleanupEntityGetId,
  getLinks: _squareFileCleanupEntityGetLinks,
  attach: _squareFileCleanupEntityAttach,
  version: '3.3.2',
);

int _squareFileCleanupEntityEstimateSize(
  SquareFileCleanupEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cidNumber.length * 3;
  bytesCount += 3 + object.cleanupKey.length * 3;
  bytesCount += 3 + object.cleanupKind.length * 3;
  bytesCount += 3 + object.draftId.length * 3;
  {
    final value = object.lastError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _squareFileCleanupEntitySerialize(
  SquareFileCleanupEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attemptCount);
  writer.writeString(offsets[1], object.cidNumber);
  writer.writeString(offsets[2], object.cleanupKey);
  writer.writeString(offsets[3], object.cleanupKind);
  writer.writeLong(offsets[4], object.createdAtMillis);
  writer.writeString(offsets[5], object.draftId);
  writer.writeString(offsets[6], object.lastError);
}

SquareFileCleanupEntity _squareFileCleanupEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SquareFileCleanupEntity();
  object.attemptCount = reader.readLong(offsets[0]);
  object.cidNumber = reader.readString(offsets[1]);
  object.cleanupKey = reader.readString(offsets[2]);
  object.cleanupKind = reader.readString(offsets[3]);
  object.createdAtMillis = reader.readLong(offsets[4]);
  object.draftId = reader.readString(offsets[5]);
  object.id = id;
  object.lastError = reader.readStringOrNull(offsets[6]);
  return object;
}

P _squareFileCleanupEntityDeserializeProp<P>(
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
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _squareFileCleanupEntityGetId(SquareFileCleanupEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _squareFileCleanupEntityGetLinks(
    SquareFileCleanupEntity object) {
  return [];
}

void _squareFileCleanupEntityAttach(
    IsarCollection<dynamic> col, Id id, SquareFileCleanupEntity object) {
  object.id = id;
}

extension SquareFileCleanupEntityByIndex
    on IsarCollection<SquareFileCleanupEntity> {
  Future<SquareFileCleanupEntity?> getByCleanupKey(String cleanupKey) {
    return getByIndex(r'cleanupKey', [cleanupKey]);
  }

  SquareFileCleanupEntity? getByCleanupKeySync(String cleanupKey) {
    return getByIndexSync(r'cleanupKey', [cleanupKey]);
  }

  Future<bool> deleteByCleanupKey(String cleanupKey) {
    return deleteByIndex(r'cleanupKey', [cleanupKey]);
  }

  bool deleteByCleanupKeySync(String cleanupKey) {
    return deleteByIndexSync(r'cleanupKey', [cleanupKey]);
  }

  Future<List<SquareFileCleanupEntity?>> getAllByCleanupKey(
      List<String> cleanupKeyValues) {
    final values = cleanupKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'cleanupKey', values);
  }

  List<SquareFileCleanupEntity?> getAllByCleanupKeySync(
      List<String> cleanupKeyValues) {
    final values = cleanupKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'cleanupKey', values);
  }

  Future<int> deleteAllByCleanupKey(List<String> cleanupKeyValues) {
    final values = cleanupKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'cleanupKey', values);
  }

  int deleteAllByCleanupKeySync(List<String> cleanupKeyValues) {
    final values = cleanupKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'cleanupKey', values);
  }

  Future<Id> putByCleanupKey(SquareFileCleanupEntity object) {
    return putByIndex(r'cleanupKey', object);
  }

  Id putByCleanupKeySync(SquareFileCleanupEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'cleanupKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCleanupKey(List<SquareFileCleanupEntity> objects) {
    return putAllByIndex(r'cleanupKey', objects);
  }

  List<Id> putAllByCleanupKeySync(List<SquareFileCleanupEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'cleanupKey', objects, saveLinks: saveLinks);
  }
}

extension SquareFileCleanupEntityQueryWhereSort
    on QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QWhere> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SquareFileCleanupEntityQueryWhere on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QWhereClause> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> cleanupKeyEqualTo(String cleanupKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cleanupKey',
        value: [cleanupKey],
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> cleanupKeyNotEqualTo(String cleanupKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cleanupKey',
              lower: [],
              upper: [cleanupKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cleanupKey',
              lower: [cleanupKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cleanupKey',
              lower: [cleanupKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cleanupKey',
              lower: [],
              upper: [cleanupKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> cidNumberEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cidNumber',
        value: [cidNumber],
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterWhereClause> cidNumberNotEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [cidNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cidNumber',
              lower: [],
              upper: [cidNumber],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SquareFileCleanupEntityQueryFilter on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QFilterCondition> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptCount',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cleanupKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cleanupKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cleanupKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cleanupKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cleanupKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cleanupKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cleanupKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cleanupKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cleanupKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cleanupKind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      cleanupKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cleanupKind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cleanupKind',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> cleanupKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cleanupKind',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'draftId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      draftIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'draftId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
          QAfterFilterCondition>
      draftIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'draftId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> draftIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'draftId',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> lastErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastError',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> lastErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastError',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
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

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastError',
        value: '',
      ));
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity,
      QAfterFilterCondition> lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastError',
        value: '',
      ));
    });
  }
}

extension SquareFileCleanupEntityQueryObject on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QFilterCondition> {}

extension SquareFileCleanupEntityQueryLinks on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QFilterCondition> {}

extension SquareFileCleanupEntityQuerySortBy
    on QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QSortBy> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCleanupKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKey', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCleanupKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKey', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCleanupKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKind', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCleanupKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKind', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }
}

extension SquareFileCleanupEntityQuerySortThenBy on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QSortThenBy> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCleanupKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKey', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCleanupKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKey', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCleanupKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKind', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCleanupKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cleanupKind', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByDraftId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByDraftIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftId', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QAfterSortBy>
      thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }
}

extension SquareFileCleanupEntityQueryWhereDistinct on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct> {
  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByCleanupKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cleanupKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByCleanupKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cleanupKind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByDraftId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draftId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SquareFileCleanupEntity, SquareFileCleanupEntity, QDistinct>
      distinctByLastError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastError', caseSensitive: caseSensitive);
    });
  }
}

extension SquareFileCleanupEntityQueryProperty on QueryBuilder<
    SquareFileCleanupEntity, SquareFileCleanupEntity, QQueryProperty> {
  QueryBuilder<SquareFileCleanupEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, int, QQueryOperations>
      attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, String, QQueryOperations>
      cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidNumber');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, String, QQueryOperations>
      cleanupKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cleanupKey');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, String, QQueryOperations>
      cleanupKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cleanupKind');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, int, QQueryOperations>
      createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, String, QQueryOperations>
      draftIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draftId');
    });
  }

  QueryBuilder<SquareFileCleanupEntity, String?, QQueryOperations>
      lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastError');
    });
  }
}
