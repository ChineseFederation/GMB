// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAdminDivisionEntityCollection on Isar {
  IsarCollection<AdminDivisionEntity> get adminDivisionEntitys =>
      this.collection();
}

const AdminDivisionEntitySchema = CollectionSchema(
  name: r'AdminDivisionEntity',
  id: 1758216221246489974,
  properties: {
    r'code': PropertySchema(
      id: 0,
      name: r'code',
      type: IsarType.string,
    ),
    r'dictVersion': PropertySchema(
      id: 1,
      name: r'dictVersion',
      type: IsarType.string,
    ),
    r'divisionKey': PropertySchema(
      id: 2,
      name: r'divisionKey',
      type: IsarType.string,
    ),
    r'divisionName': PropertySchema(
      id: 3,
      name: r'divisionName',
      type: IsarType.string,
    ),
    r'level': PropertySchema(
      id: 4,
      name: r'level',
      type: IsarType.string,
    ),
    r'scopeKey': PropertySchema(
      id: 5,
      name: r'scopeKey',
      type: IsarType.string,
    )
  },
  estimateSize: _adminDivisionEntityEstimateSize,
  serialize: _adminDivisionEntitySerialize,
  deserialize: _adminDivisionEntityDeserialize,
  deserializeProp: _adminDivisionEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'divisionKey': IndexSchema(
      id: -3591502739809730185,
      name: r'divisionKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'divisionKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'level': IndexSchema(
      id: -730704511986726349,
      name: r'level',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'level',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'scopeKey': IndexSchema(
      id: -388923758492624597,
      name: r'scopeKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'scopeKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _adminDivisionEntityGetId,
  getLinks: _adminDivisionEntityGetLinks,
  attach: _adminDivisionEntityAttach,
  version: '3.3.2',
);

int _adminDivisionEntityEstimateSize(
  AdminDivisionEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.code.length * 3;
  {
    final value = object.dictVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.divisionKey.length * 3;
  bytesCount += 3 + object.divisionName.length * 3;
  bytesCount += 3 + object.level.length * 3;
  bytesCount += 3 + object.scopeKey.length * 3;
  return bytesCount;
}

void _adminDivisionEntitySerialize(
  AdminDivisionEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.code);
  writer.writeString(offsets[1], object.dictVersion);
  writer.writeString(offsets[2], object.divisionKey);
  writer.writeString(offsets[3], object.divisionName);
  writer.writeString(offsets[4], object.level);
  writer.writeString(offsets[5], object.scopeKey);
}

AdminDivisionEntity _adminDivisionEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AdminDivisionEntity();
  object.code = reader.readString(offsets[0]);
  object.dictVersion = reader.readStringOrNull(offsets[1]);
  object.divisionKey = reader.readString(offsets[2]);
  object.divisionName = reader.readString(offsets[3]);
  object.id = id;
  object.level = reader.readString(offsets[4]);
  object.scopeKey = reader.readString(offsets[5]);
  return object;
}

P _adminDivisionEntityDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _adminDivisionEntityGetId(AdminDivisionEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _adminDivisionEntityGetLinks(
    AdminDivisionEntity object) {
  return [];
}

void _adminDivisionEntityAttach(
    IsarCollection<dynamic> col, Id id, AdminDivisionEntity object) {
  object.id = id;
}

extension AdminDivisionEntityByIndex on IsarCollection<AdminDivisionEntity> {
  Future<AdminDivisionEntity?> getByDivisionKey(String divisionKey) {
    return getByIndex(r'divisionKey', [divisionKey]);
  }

  AdminDivisionEntity? getByDivisionKeySync(String divisionKey) {
    return getByIndexSync(r'divisionKey', [divisionKey]);
  }

  Future<bool> deleteByDivisionKey(String divisionKey) {
    return deleteByIndex(r'divisionKey', [divisionKey]);
  }

  bool deleteByDivisionKeySync(String divisionKey) {
    return deleteByIndexSync(r'divisionKey', [divisionKey]);
  }

  Future<List<AdminDivisionEntity?>> getAllByDivisionKey(
      List<String> divisionKeyValues) {
    final values = divisionKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'divisionKey', values);
  }

  List<AdminDivisionEntity?> getAllByDivisionKeySync(
      List<String> divisionKeyValues) {
    final values = divisionKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'divisionKey', values);
  }

  Future<int> deleteAllByDivisionKey(List<String> divisionKeyValues) {
    final values = divisionKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'divisionKey', values);
  }

  int deleteAllByDivisionKeySync(List<String> divisionKeyValues) {
    final values = divisionKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'divisionKey', values);
  }

  Future<Id> putByDivisionKey(AdminDivisionEntity object) {
    return putByIndex(r'divisionKey', object);
  }

  Id putByDivisionKeySync(AdminDivisionEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'divisionKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDivisionKey(List<AdminDivisionEntity> objects) {
    return putAllByIndex(r'divisionKey', objects);
  }

  List<Id> putAllByDivisionKeySync(List<AdminDivisionEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'divisionKey', objects, saveLinks: saveLinks);
  }
}

extension AdminDivisionEntityQueryWhereSort
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QWhere> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AdminDivisionEntityQueryWhere
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QWhereClause> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
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

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
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

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      divisionKeyEqualTo(String divisionKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'divisionKey',
        value: [divisionKey],
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      divisionKeyNotEqualTo(String divisionKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'divisionKey',
              lower: [],
              upper: [divisionKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'divisionKey',
              lower: [divisionKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'divisionKey',
              lower: [divisionKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'divisionKey',
              lower: [],
              upper: [divisionKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      levelEqualTo(String level) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'level',
        value: [level],
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      levelNotEqualTo(String level) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'level',
              lower: [],
              upper: [level],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'level',
              lower: [level],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'level',
              lower: [level],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'level',
              lower: [],
              upper: [level],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      scopeKeyEqualTo(String scopeKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'scopeKey',
        value: [scopeKey],
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterWhereClause>
      scopeKeyNotEqualTo(String scopeKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scopeKey',
              lower: [],
              upper: [scopeKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scopeKey',
              lower: [scopeKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scopeKey',
              lower: [scopeKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'scopeKey',
              lower: [],
              upper: [scopeKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AdminDivisionEntityQueryFilter on QueryBuilder<AdminDivisionEntity,
    AdminDivisionEntity, QFilterCondition> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'code',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'code',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      codeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dictVersion',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dictVersion',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dictVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dictVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dictVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dictVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      dictVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dictVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'divisionKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'divisionKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'divisionKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'divisionKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'divisionKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'divisionName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'divisionName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'divisionName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'divisionName',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      divisionNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'divisionName',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
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

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
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

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
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

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'level',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'level',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'level',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'level',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      levelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'level',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scopeKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'scopeKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'scopeKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterFilterCondition>
      scopeKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'scopeKey',
        value: '',
      ));
    });
  }
}

extension AdminDivisionEntityQueryObject on QueryBuilder<AdminDivisionEntity,
    AdminDivisionEntity, QFilterCondition> {}

extension AdminDivisionEntityQueryLinks on QueryBuilder<AdminDivisionEntity,
    AdminDivisionEntity, QFilterCondition> {}

extension AdminDivisionEntityQuerySortBy
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QSortBy> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDictVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictVersion', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDictVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictVersion', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDivisionKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionKey', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDivisionKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionKey', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDivisionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionName', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByDivisionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionName', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByScopeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeKey', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      sortByScopeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeKey', Sort.desc);
    });
  }
}

extension AdminDivisionEntityQuerySortThenBy
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QSortThenBy> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDictVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictVersion', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDictVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dictVersion', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDivisionKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionKey', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDivisionKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionKey', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDivisionName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionName', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByDivisionNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'divisionName', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'level', Sort.desc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByScopeKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeKey', Sort.asc);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QAfterSortBy>
      thenByScopeKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeKey', Sort.desc);
    });
  }
}

extension AdminDivisionEntityQueryWhereDistinct
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct> {
  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByDictVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dictVersion', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByDivisionKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'divisionKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByDivisionName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'divisionName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByLevel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'level', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QDistinct>
      distinctByScopeKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scopeKey', caseSensitive: caseSensitive);
    });
  }
}

extension AdminDivisionEntityQueryProperty
    on QueryBuilder<AdminDivisionEntity, AdminDivisionEntity, QQueryProperty> {
  QueryBuilder<AdminDivisionEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AdminDivisionEntity, String, QQueryOperations> codeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'code');
    });
  }

  QueryBuilder<AdminDivisionEntity, String?, QQueryOperations>
      dictVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dictVersion');
    });
  }

  QueryBuilder<AdminDivisionEntity, String, QQueryOperations>
      divisionKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'divisionKey');
    });
  }

  QueryBuilder<AdminDivisionEntity, String, QQueryOperations>
      divisionNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'divisionName');
    });
  }

  QueryBuilder<AdminDivisionEntity, String, QQueryOperations> levelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'level');
    });
  }

  QueryBuilder<AdminDivisionEntity, String, QQueryOperations>
      scopeKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scopeKey');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPublicInstitutionEntityCollection on Isar {
  IsarCollection<PublicInstitutionEntity> get publicInstitutionEntitys =>
      this.collection();
}

const PublicInstitutionEntitySchema = CollectionSchema(
  name: r'PublicInstitutionEntity',
  id: 1125869609343849778,
  properties: {
    r'accountCount': PropertySchema(
      id: 0,
      name: r'accountCount',
      type: IsarType.long,
    ),
    r'catalogVersion': PropertySchema(
      id: 1,
      name: r'catalogVersion',
      type: IsarType.string,
    ),
    r'cidFullName': PropertySchema(
      id: 2,
      name: r'cidFullName',
      type: IsarType.string,
    ),
    r'cidNumber': PropertySchema(
      id: 3,
      name: r'cidNumber',
      type: IsarType.string,
    ),
    r'cidShortName': PropertySchema(
      id: 4,
      name: r'cidShortName',
      type: IsarType.string,
    ),
    r'cityCode': PropertySchema(
      id: 5,
      name: r'cityCode',
      type: IsarType.string,
    ),
    r'customAccountNames': PropertySchema(
      id: 6,
      name: r'customAccountNames',
      type: IsarType.stringList,
    ),
    r'familyName': PropertySchema(
      id: 7,
      name: r'familyName',
      type: IsarType.string,
    ),
    r'givenName': PropertySchema(
      id: 8,
      name: r'givenName',
      type: IsarType.string,
    ),
    r'hasLegalPersonality': PropertySchema(
      id: 9,
      name: r'hasLegalPersonality',
      type: IsarType.bool,
    ),
    r'institutionCode': PropertySchema(
      id: 10,
      name: r'institutionCode',
      type: IsarType.string,
    ),
    r'legalRepresentativeAccountId': PropertySchema(
      id: 11,
      name: r'legalRepresentativeAccountId',
      type: IsarType.string,
    ),
    r'legalRepresentativeCidNumber': PropertySchema(
      id: 12,
      name: r'legalRepresentativeCidNumber',
      type: IsarType.string,
    ),
    r'parentCidNumber': PropertySchema(
      id: 13,
      name: r'parentCidNumber',
      type: IsarType.string,
    ),
    r'provinceCode': PropertySchema(
      id: 14,
      name: r'provinceCode',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 15,
      name: r'status',
      type: IsarType.string,
    ),
    r'townCode': PropertySchema(
      id: 16,
      name: r'townCode',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 17,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _publicInstitutionEntityEstimateSize,
  serialize: _publicInstitutionEntitySerialize,
  deserialize: _publicInstitutionEntityDeserialize,
  deserializeProp: _publicInstitutionEntityDeserializeProp,
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
    ),
    r'provinceCode': IndexSchema(
      id: 8657952105404471208,
      name: r'provinceCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'provinceCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'cityCode': IndexSchema(
      id: 8629940939212169001,
      name: r'cityCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'cityCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'institutionCode': IndexSchema(
      id: 4992077277898828048,
      name: r'institutionCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'institutionCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _publicInstitutionEntityGetId,
  getLinks: _publicInstitutionEntityGetLinks,
  attach: _publicInstitutionEntityAttach,
  version: '3.3.2',
);

int _publicInstitutionEntityEstimateSize(
  PublicInstitutionEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.catalogVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cidFullName.length * 3;
  bytesCount += 3 + object.cidNumber.length * 3;
  {
    final value = object.cidShortName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cityCode.length * 3;
  bytesCount += 3 + object.customAccountNames.length * 3;
  {
    for (var i = 0; i < object.customAccountNames.length; i++) {
      final value = object.customAccountNames[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.familyName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.givenName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.institutionCode.length * 3;
  {
    final value = object.legalRepresentativeAccountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.legalRepresentativeCidNumber;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.parentCidNumber;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.provinceCode.length * 3;
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.townCode.length * 3;
  return bytesCount;
}

void _publicInstitutionEntitySerialize(
  PublicInstitutionEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.accountCount);
  writer.writeString(offsets[1], object.catalogVersion);
  writer.writeString(offsets[2], object.cidFullName);
  writer.writeString(offsets[3], object.cidNumber);
  writer.writeString(offsets[4], object.cidShortName);
  writer.writeString(offsets[5], object.cityCode);
  writer.writeStringList(offsets[6], object.customAccountNames);
  writer.writeString(offsets[7], object.familyName);
  writer.writeString(offsets[8], object.givenName);
  writer.writeBool(offsets[9], object.hasLegalPersonality);
  writer.writeString(offsets[10], object.institutionCode);
  writer.writeString(offsets[11], object.legalRepresentativeAccountId);
  writer.writeString(offsets[12], object.legalRepresentativeCidNumber);
  writer.writeString(offsets[13], object.parentCidNumber);
  writer.writeString(offsets[14], object.provinceCode);
  writer.writeString(offsets[15], object.status);
  writer.writeString(offsets[16], object.townCode);
  writer.writeLong(offsets[17], object.updatedAtMillis);
}

PublicInstitutionEntity _publicInstitutionEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PublicInstitutionEntity();
  object.accountCount = reader.readLong(offsets[0]);
  object.catalogVersion = reader.readStringOrNull(offsets[1]);
  object.cidFullName = reader.readString(offsets[2]);
  object.cidNumber = reader.readString(offsets[3]);
  object.cidShortName = reader.readStringOrNull(offsets[4]);
  object.cityCode = reader.readString(offsets[5]);
  object.customAccountNames = reader.readStringList(offsets[6]) ?? [];
  object.familyName = reader.readStringOrNull(offsets[7]);
  object.givenName = reader.readStringOrNull(offsets[8]);
  object.hasLegalPersonality = reader.readBoolOrNull(offsets[9]);
  object.id = id;
  object.institutionCode = reader.readString(offsets[10]);
  object.legalRepresentativeAccountId = reader.readStringOrNull(offsets[11]);
  object.legalRepresentativeCidNumber = reader.readStringOrNull(offsets[12]);
  object.parentCidNumber = reader.readStringOrNull(offsets[13]);
  object.provinceCode = reader.readString(offsets[14]);
  object.status = reader.readString(offsets[15]);
  object.townCode = reader.readString(offsets[16]);
  object.updatedAtMillis = reader.readLong(offsets[17]);
  return object;
}

P _publicInstitutionEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? []) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBoolOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _publicInstitutionEntityGetId(PublicInstitutionEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _publicInstitutionEntityGetLinks(
    PublicInstitutionEntity object) {
  return [];
}

void _publicInstitutionEntityAttach(
    IsarCollection<dynamic> col, Id id, PublicInstitutionEntity object) {
  object.id = id;
}

extension PublicInstitutionEntityByIndex
    on IsarCollection<PublicInstitutionEntity> {
  Future<PublicInstitutionEntity?> getByCidNumber(String cidNumber) {
    return getByIndex(r'cidNumber', [cidNumber]);
  }

  PublicInstitutionEntity? getByCidNumberSync(String cidNumber) {
    return getByIndexSync(r'cidNumber', [cidNumber]);
  }

  Future<bool> deleteByCidNumber(String cidNumber) {
    return deleteByIndex(r'cidNumber', [cidNumber]);
  }

  bool deleteByCidNumberSync(String cidNumber) {
    return deleteByIndexSync(r'cidNumber', [cidNumber]);
  }

  Future<List<PublicInstitutionEntity?>> getAllByCidNumber(
      List<String> cidNumberValues) {
    final values = cidNumberValues.map((e) => [e]).toList();
    return getAllByIndex(r'cidNumber', values);
  }

  List<PublicInstitutionEntity?> getAllByCidNumberSync(
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

  Future<Id> putByCidNumber(PublicInstitutionEntity object) {
    return putByIndex(r'cidNumber', object);
  }

  Id putByCidNumberSync(PublicInstitutionEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'cidNumber', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCidNumber(List<PublicInstitutionEntity> objects) {
    return putAllByIndex(r'cidNumber', objects);
  }

  List<Id> putAllByCidNumberSync(List<PublicInstitutionEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'cidNumber', objects, saveLinks: saveLinks);
  }
}

extension PublicInstitutionEntityQueryWhereSort
    on QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QWhere> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PublicInstitutionEntityQueryWhere on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QWhereClause> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> cidNumberEqualTo(String cidNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cidNumber',
        value: [cidNumber],
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> provinceCodeEqualTo(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'provinceCode',
        value: [provinceCode],
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> provinceCodeNotEqualTo(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [],
              upper: [provinceCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [provinceCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [provinceCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [],
              upper: [provinceCode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> cityCodeEqualTo(String cityCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'cityCode',
        value: [cityCode],
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> cityCodeNotEqualTo(String cityCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cityCode',
              lower: [],
              upper: [cityCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cityCode',
              lower: [cityCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cityCode',
              lower: [cityCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'cityCode',
              lower: [],
              upper: [cityCode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> institutionCodeEqualTo(String institutionCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'institutionCode',
        value: [institutionCode],
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterWhereClause> institutionCodeNotEqualTo(String institutionCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'institutionCode',
              lower: [],
              upper: [institutionCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'institutionCode',
              lower: [institutionCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'institutionCode',
              lower: [institutionCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'institutionCode',
              lower: [],
              upper: [institutionCode],
              includeUpper: false,
            ));
      }
    });
  }
}

extension PublicInstitutionEntityQueryFilter on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QFilterCondition> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> accountCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'accountCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> accountCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'accountCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> accountCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'accountCount',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> accountCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'accountCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'catalogVersion',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'catalogVersion',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'catalogVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      catalogVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'catalogVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      catalogVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'catalogVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'catalogVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> catalogVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'catalogVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidFullName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cidFullNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidFullName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cidFullNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidFullName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidFullName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidFullNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidFullName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cidShortName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cidShortName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cidShortName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cidShortNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cidShortName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cidShortNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cidShortName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cidShortName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cidShortNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cidShortName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cityCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cityCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cityCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      cityCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cityCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cityCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> cityCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cityCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customAccountNames',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      customAccountNamesElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customAccountNames',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      customAccountNamesElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customAccountNames',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customAccountNames',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customAccountNames',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> customAccountNamesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'customAccountNames',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'familyName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'familyName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'familyName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      familyNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'familyName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      familyNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'familyName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'familyName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> familyNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'familyName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'givenName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'givenName',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'givenName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      givenNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'givenName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      givenNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'givenName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'givenName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> givenNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'givenName',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> hasLegalPersonalityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'hasLegalPersonality',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> hasLegalPersonalityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'hasLegalPersonality',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> hasLegalPersonalityEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasLegalPersonality',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'institutionCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      institutionCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'institutionCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      institutionCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'institutionCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'institutionCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> institutionCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'institutionCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'legalRepresentativeAccountId',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'legalRepresentativeAccountId',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'legalRepresentativeAccountId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      legalRepresentativeAccountIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'legalRepresentativeAccountId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      legalRepresentativeAccountIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'legalRepresentativeAccountId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'legalRepresentativeAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeAccountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'legalRepresentativeAccountId',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'legalRepresentativeCidNumber',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'legalRepresentativeCidNumber',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'legalRepresentativeCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      legalRepresentativeCidNumberContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'legalRepresentativeCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      legalRepresentativeCidNumberMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'legalRepresentativeCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'legalRepresentativeCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> legalRepresentativeCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'legalRepresentativeCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parentCidNumber',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parentCidNumber',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parentCidNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      parentCidNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'parentCidNumber',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      parentCidNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'parentCidNumber',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> parentCidNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'parentCidNumber',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provinceCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      provinceCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      provinceCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'provinceCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> provinceCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'provinceCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'townCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      townCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'townCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
          QAfterFilterCondition>
      townCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'townCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'townCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> townCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'townCode',
        value: '',
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity,
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

extension PublicInstitutionEntityQueryObject on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QFilterCondition> {}

extension PublicInstitutionEntityQueryLinks on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QFilterCondition> {}

extension PublicInstitutionEntityQuerySortBy
    on QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QSortBy> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountCount', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByAccountCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountCount', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCatalogVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'catalogVersion', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCatalogVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'catalogVersion', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidFullName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidFullName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidFullNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidFullName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidShortName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidShortName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCidShortNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidShortName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cityCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cityCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByFamilyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'familyName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByFamilyNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'familyName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByGivenName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'givenName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByGivenNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'givenName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByHasLegalPersonality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLegalPersonality', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByHasLegalPersonalityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLegalPersonality', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByInstitutionCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'institutionCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByInstitutionCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'institutionCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByLegalRepresentativeAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeAccountId', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByLegalRepresentativeAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeAccountId', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByLegalRepresentativeCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeCidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByLegalRepresentativeCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeCidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByParentCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentCidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByParentCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentCidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'townCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'townCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension PublicInstitutionEntityQuerySortThenBy on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QSortThenBy> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountCount', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByAccountCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountCount', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCatalogVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'catalogVersion', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCatalogVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'catalogVersion', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidFullName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidFullName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidFullNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidFullName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidShortName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidShortName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCidShortNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cidShortName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCityCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cityCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByCityCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cityCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByFamilyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'familyName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByFamilyNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'familyName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByGivenName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'givenName', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByGivenNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'givenName', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByHasLegalPersonality() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLegalPersonality', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByHasLegalPersonalityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLegalPersonality', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByInstitutionCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'institutionCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByInstitutionCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'institutionCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByLegalRepresentativeAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeAccountId', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByLegalRepresentativeAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeAccountId', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByLegalRepresentativeCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeCidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByLegalRepresentativeCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'legalRepresentativeCidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByParentCidNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentCidNumber', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByParentCidNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentCidNumber', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByTownCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'townCode', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByTownCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'townCode', Sort.desc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension PublicInstitutionEntityQueryWhereDistinct on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QDistinct> {
  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByAccountCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountCount');
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCatalogVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'catalogVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCidFullName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidFullName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidNumber', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCidShortName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cidShortName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCityCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cityCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByCustomAccountNames() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customAccountNames');
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByFamilyName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'familyName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByGivenName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'givenName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByHasLegalPersonality() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasLegalPersonality');
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByInstitutionCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'institutionCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByLegalRepresentativeAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'legalRepresentativeAccountId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByLegalRepresentativeCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'legalRepresentativeCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByParentCidNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentCidNumber',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByProvinceCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provinceCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByTownCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'townCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PublicInstitutionEntity, PublicInstitutionEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension PublicInstitutionEntityQueryProperty on QueryBuilder<
    PublicInstitutionEntity, PublicInstitutionEntity, QQueryProperty> {
  QueryBuilder<PublicInstitutionEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PublicInstitutionEntity, int, QQueryOperations>
      accountCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountCount');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      catalogVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'catalogVersion');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      cidFullNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidFullName');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      cidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidNumber');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      cidShortNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cidShortName');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      cityCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cityCode');
    });
  }

  QueryBuilder<PublicInstitutionEntity, List<String>, QQueryOperations>
      customAccountNamesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customAccountNames');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      familyNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'familyName');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      givenNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'givenName');
    });
  }

  QueryBuilder<PublicInstitutionEntity, bool?, QQueryOperations>
      hasLegalPersonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasLegalPersonality');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      institutionCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'institutionCode');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      legalRepresentativeAccountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'legalRepresentativeAccountId');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      legalRepresentativeCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'legalRepresentativeCidNumber');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String?, QQueryOperations>
      parentCidNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentCidNumber');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      provinceCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provinceCode');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<PublicInstitutionEntity, String, QQueryOperations>
      townCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'townCode');
    });
  }

  QueryBuilder<PublicInstitutionEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppDataVersionEntityCollection on Isar {
  IsarCollection<AppDataVersionEntity> get appDataVersionEntitys =>
      this.collection();
}

const AppDataVersionEntitySchema = CollectionSchema(
  name: r'AppDataVersionEntity',
  id: -7313895477984256057,
  properties: {
    r'globalVersion': PropertySchema(
      id: 0,
      name: r'globalVersion',
      type: IsarType.string,
    ),
    r'namespace': PropertySchema(
      id: 1,
      name: r'namespace',
      type: IsarType.string,
    ),
    r'provinceVersionsJson': PropertySchema(
      id: 2,
      name: r'provinceVersionsJson',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 3,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _appDataVersionEntityEstimateSize,
  serialize: _appDataVersionEntitySerialize,
  deserialize: _appDataVersionEntityDeserialize,
  deserializeProp: _appDataVersionEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'namespace': IndexSchema(
      id: 2334977328868235416,
      name: r'namespace',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'namespace',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _appDataVersionEntityGetId,
  getLinks: _appDataVersionEntityGetLinks,
  attach: _appDataVersionEntityAttach,
  version: '3.3.2',
);

int _appDataVersionEntityEstimateSize(
  AppDataVersionEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.globalVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.namespace.length * 3;
  {
    final value = object.provinceVersionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _appDataVersionEntitySerialize(
  AppDataVersionEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.globalVersion);
  writer.writeString(offsets[1], object.namespace);
  writer.writeString(offsets[2], object.provinceVersionsJson);
  writer.writeLong(offsets[3], object.updatedAtMillis);
}

AppDataVersionEntity _appDataVersionEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppDataVersionEntity();
  object.globalVersion = reader.readStringOrNull(offsets[0]);
  object.id = id;
  object.namespace = reader.readString(offsets[1]);
  object.provinceVersionsJson = reader.readStringOrNull(offsets[2]);
  object.updatedAtMillis = reader.readLong(offsets[3]);
  return object;
}

P _appDataVersionEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appDataVersionEntityGetId(AppDataVersionEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appDataVersionEntityGetLinks(
    AppDataVersionEntity object) {
  return [];
}

void _appDataVersionEntityAttach(
    IsarCollection<dynamic> col, Id id, AppDataVersionEntity object) {
  object.id = id;
}

extension AppDataVersionEntityByIndex on IsarCollection<AppDataVersionEntity> {
  Future<AppDataVersionEntity?> getByNamespace(String namespace) {
    return getByIndex(r'namespace', [namespace]);
  }

  AppDataVersionEntity? getByNamespaceSync(String namespace) {
    return getByIndexSync(r'namespace', [namespace]);
  }

  Future<bool> deleteByNamespace(String namespace) {
    return deleteByIndex(r'namespace', [namespace]);
  }

  bool deleteByNamespaceSync(String namespace) {
    return deleteByIndexSync(r'namespace', [namespace]);
  }

  Future<List<AppDataVersionEntity?>> getAllByNamespace(
      List<String> namespaceValues) {
    final values = namespaceValues.map((e) => [e]).toList();
    return getAllByIndex(r'namespace', values);
  }

  List<AppDataVersionEntity?> getAllByNamespaceSync(
      List<String> namespaceValues) {
    final values = namespaceValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'namespace', values);
  }

  Future<int> deleteAllByNamespace(List<String> namespaceValues) {
    final values = namespaceValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'namespace', values);
  }

  int deleteAllByNamespaceSync(List<String> namespaceValues) {
    final values = namespaceValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'namespace', values);
  }

  Future<Id> putByNamespace(AppDataVersionEntity object) {
    return putByIndex(r'namespace', object);
  }

  Id putByNamespaceSync(AppDataVersionEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'namespace', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByNamespace(List<AppDataVersionEntity> objects) {
    return putAllByIndex(r'namespace', objects);
  }

  List<Id> putAllByNamespaceSync(List<AppDataVersionEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'namespace', objects, saveLinks: saveLinks);
  }
}

extension AppDataVersionEntityQueryWhereSort
    on QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QWhere> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppDataVersionEntityQueryWhere
    on QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QWhereClause> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
      namespaceEqualTo(String namespace) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'namespace',
        value: [namespace],
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterWhereClause>
      namespaceNotEqualTo(String namespace) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'namespace',
              lower: [],
              upper: [namespace],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'namespace',
              lower: [namespace],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'namespace',
              lower: [namespace],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'namespace',
              lower: [],
              upper: [namespace],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AppDataVersionEntityQueryFilter on QueryBuilder<AppDataVersionEntity,
    AppDataVersionEntity, QFilterCondition> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'globalVersion',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'globalVersion',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'globalVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      globalVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'globalVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      globalVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'globalVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'globalVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> globalVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'globalVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'namespace',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      namespaceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'namespace',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      namespaceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'namespace',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'namespace',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> namespaceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'namespace',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'provinceVersionsJson',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'provinceVersionsJson',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provinceVersionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      provinceVersionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'provinceVersionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
          QAfterFilterCondition>
      provinceVersionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'provinceVersionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceVersionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> provinceVersionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'provinceVersionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity,
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

extension AppDataVersionEntityQueryObject on QueryBuilder<AppDataVersionEntity,
    AppDataVersionEntity, QFilterCondition> {}

extension AppDataVersionEntityQueryLinks on QueryBuilder<AppDataVersionEntity,
    AppDataVersionEntity, QFilterCondition> {}

extension AppDataVersionEntityQuerySortBy
    on QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QSortBy> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByGlobalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalVersion', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByGlobalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalVersion', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByNamespace() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'namespace', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByNamespaceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'namespace', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByProvinceVersionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceVersionsJson', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByProvinceVersionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceVersionsJson', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension AppDataVersionEntityQuerySortThenBy
    on QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QSortThenBy> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByGlobalVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalVersion', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByGlobalVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalVersion', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByNamespace() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'namespace', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByNamespaceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'namespace', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByProvinceVersionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceVersionsJson', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByProvinceVersionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceVersionsJson', Sort.desc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QAfterSortBy>
      thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension AppDataVersionEntityQueryWhereDistinct
    on QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QDistinct> {
  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QDistinct>
      distinctByGlobalVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'globalVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QDistinct>
      distinctByNamespace({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'namespace', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QDistinct>
      distinctByProvinceVersionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provinceVersionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppDataVersionEntity, AppDataVersionEntity, QDistinct>
      distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension AppDataVersionEntityQueryProperty on QueryBuilder<
    AppDataVersionEntity, AppDataVersionEntity, QQueryProperty> {
  QueryBuilder<AppDataVersionEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppDataVersionEntity, String?, QQueryOperations>
      globalVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'globalVersion');
    });
  }

  QueryBuilder<AppDataVersionEntity, String, QQueryOperations>
      namespaceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'namespace');
    });
  }

  QueryBuilder<AppDataVersionEntity, String?, QQueryOperations>
      provinceVersionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provinceVersionsJson');
    });
  }

  QueryBuilder<AppDataVersionEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppPublicInstitutionCatalogEntityCollection on Isar {
  IsarCollection<AppPublicInstitutionCatalogEntity>
      get appPublicInstitutionCatalogEntitys => this.collection();
}

const AppPublicInstitutionCatalogEntitySchema = CollectionSchema(
  name: r'AppPublicInstitutionCatalogEntity',
  id: -5158935390252709386,
  properties: {
    r'provinceCodes': PropertySchema(
      id: 0,
      name: r'provinceCodes',
      type: IsarType.stringList,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 1,
      name: r'updatedAtMillis',
      type: IsarType.long,
    )
  },
  estimateSize: _appPublicInstitutionCatalogEntityEstimateSize,
  serialize: _appPublicInstitutionCatalogEntitySerialize,
  deserialize: _appPublicInstitutionCatalogEntityDeserialize,
  deserializeProp: _appPublicInstitutionCatalogEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appPublicInstitutionCatalogEntityGetId,
  getLinks: _appPublicInstitutionCatalogEntityGetLinks,
  attach: _appPublicInstitutionCatalogEntityAttach,
  version: '3.3.2',
);

int _appPublicInstitutionCatalogEntityEstimateSize(
  AppPublicInstitutionCatalogEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.provinceCodes.length * 3;
  {
    for (var i = 0; i < object.provinceCodes.length; i++) {
      final value = object.provinceCodes[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _appPublicInstitutionCatalogEntitySerialize(
  AppPublicInstitutionCatalogEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.provinceCodes);
  writer.writeLong(offsets[1], object.updatedAtMillis);
}

AppPublicInstitutionCatalogEntity _appPublicInstitutionCatalogEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppPublicInstitutionCatalogEntity();
  object.id = id;
  object.provinceCodes = reader.readStringList(offsets[0]) ?? [];
  object.updatedAtMillis = reader.readLong(offsets[1]);
  return object;
}

P _appPublicInstitutionCatalogEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appPublicInstitutionCatalogEntityGetId(
    AppPublicInstitutionCatalogEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appPublicInstitutionCatalogEntityGetLinks(
    AppPublicInstitutionCatalogEntity object) {
  return [];
}

void _appPublicInstitutionCatalogEntityAttach(IsarCollection<dynamic> col,
    Id id, AppPublicInstitutionCatalogEntity object) {
  object.id = id;
}

extension AppPublicInstitutionCatalogEntityQueryWhereSort on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QWhere> {
  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppPublicInstitutionCatalogEntityQueryWhere on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QWhereClause> {
  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
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

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterWhereClause> idBetween(
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
}

extension AppPublicInstitutionCatalogEntityQueryFilter on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QFilterCondition> {
  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provinceCodes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
          AppPublicInstitutionCatalogEntity, QAfterFilterCondition>
      provinceCodesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'provinceCodes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
          AppPublicInstitutionCatalogEntity, QAfterFilterCondition>
      provinceCodesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'provinceCodes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCodes',
        value: '',
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'provinceCodes',
        value: '',
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> provinceCodesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'provinceCodes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
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

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
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

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
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

extension AppPublicInstitutionCatalogEntityQueryObject on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QFilterCondition> {}

extension AppPublicInstitutionCatalogEntityQueryLinks on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QFilterCondition> {}

extension AppPublicInstitutionCatalogEntityQuerySortBy on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QSortBy> {
  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterSortBy> sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterSortBy> sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension AppPublicInstitutionCatalogEntityQuerySortThenBy on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QSortThenBy> {
  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QAfterSortBy> thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QAfterSortBy> thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension AppPublicInstitutionCatalogEntityQueryWhereDistinct on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QDistinct> {
  QueryBuilder<AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity, QDistinct> distinctByProvinceCodes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provinceCodes');
    });
  }

  QueryBuilder<
      AppPublicInstitutionCatalogEntity,
      AppPublicInstitutionCatalogEntity,
      QDistinct> distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension AppPublicInstitutionCatalogEntityQueryProperty on QueryBuilder<
    AppPublicInstitutionCatalogEntity,
    AppPublicInstitutionCatalogEntity,
    QQueryProperty> {
  QueryBuilder<AppPublicInstitutionCatalogEntity, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity, List<String>,
      QQueryOperations> provinceCodesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provinceCodes');
    });
  }

  QueryBuilder<AppPublicInstitutionCatalogEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppPublicInstitutionProvinceVersionEntityCollection on Isar {
  IsarCollection<AppPublicInstitutionProvinceVersionEntity>
      get appPublicInstitutionProvinceVersionEntitys => this.collection();
}

const AppPublicInstitutionProvinceVersionEntitySchema = CollectionSchema(
  name: r'AppPublicInstitutionProvinceVersionEntity',
  id: 8451337890384738738,
  properties: {
    r'provinceCode': PropertySchema(
      id: 0,
      name: r'provinceCode',
      type: IsarType.string,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 1,
      name: r'updatedAtMillis',
      type: IsarType.long,
    ),
    r'version': PropertySchema(
      id: 2,
      name: r'version',
      type: IsarType.string,
    )
  },
  estimateSize: _appPublicInstitutionProvinceVersionEntityEstimateSize,
  serialize: _appPublicInstitutionProvinceVersionEntitySerialize,
  deserialize: _appPublicInstitutionProvinceVersionEntityDeserialize,
  deserializeProp: _appPublicInstitutionProvinceVersionEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'provinceCode': IndexSchema(
      id: 8657952105404471208,
      name: r'provinceCode',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'provinceCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _appPublicInstitutionProvinceVersionEntityGetId,
  getLinks: _appPublicInstitutionProvinceVersionEntityGetLinks,
  attach: _appPublicInstitutionProvinceVersionEntityAttach,
  version: '3.3.2',
);

int _appPublicInstitutionProvinceVersionEntityEstimateSize(
  AppPublicInstitutionProvinceVersionEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.provinceCode.length * 3;
  bytesCount += 3 + object.version.length * 3;
  return bytesCount;
}

void _appPublicInstitutionProvinceVersionEntitySerialize(
  AppPublicInstitutionProvinceVersionEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.provinceCode);
  writer.writeLong(offsets[1], object.updatedAtMillis);
  writer.writeString(offsets[2], object.version);
}

AppPublicInstitutionProvinceVersionEntity
    _appPublicInstitutionProvinceVersionEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppPublicInstitutionProvinceVersionEntity();
  object.id = id;
  object.provinceCode = reader.readString(offsets[0]);
  object.updatedAtMillis = reader.readLong(offsets[1]);
  object.version = reader.readString(offsets[2]);
  return object;
}

P _appPublicInstitutionProvinceVersionEntityDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appPublicInstitutionProvinceVersionEntityGetId(
    AppPublicInstitutionProvinceVersionEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appPublicInstitutionProvinceVersionEntityGetLinks(
    AppPublicInstitutionProvinceVersionEntity object) {
  return [];
}

void _appPublicInstitutionProvinceVersionEntityAttach(
    IsarCollection<dynamic> col,
    Id id,
    AppPublicInstitutionProvinceVersionEntity object) {
  object.id = id;
}

extension AppPublicInstitutionProvinceVersionEntityByIndex
    on IsarCollection<AppPublicInstitutionProvinceVersionEntity> {
  Future<AppPublicInstitutionProvinceVersionEntity?> getByProvinceCode(
      String provinceCode) {
    return getByIndex(r'provinceCode', [provinceCode]);
  }

  AppPublicInstitutionProvinceVersionEntity? getByProvinceCodeSync(
      String provinceCode) {
    return getByIndexSync(r'provinceCode', [provinceCode]);
  }

  Future<bool> deleteByProvinceCode(String provinceCode) {
    return deleteByIndex(r'provinceCode', [provinceCode]);
  }

  bool deleteByProvinceCodeSync(String provinceCode) {
    return deleteByIndexSync(r'provinceCode', [provinceCode]);
  }

  Future<List<AppPublicInstitutionProvinceVersionEntity?>> getAllByProvinceCode(
      List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return getAllByIndex(r'provinceCode', values);
  }

  List<AppPublicInstitutionProvinceVersionEntity?> getAllByProvinceCodeSync(
      List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'provinceCode', values);
  }

  Future<int> deleteAllByProvinceCode(List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'provinceCode', values);
  }

  int deleteAllByProvinceCodeSync(List<String> provinceCodeValues) {
    final values = provinceCodeValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'provinceCode', values);
  }

  Future<Id> putByProvinceCode(
      AppPublicInstitutionProvinceVersionEntity object) {
    return putByIndex(r'provinceCode', object);
  }

  Id putByProvinceCodeSync(AppPublicInstitutionProvinceVersionEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'provinceCode', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProvinceCode(
      List<AppPublicInstitutionProvinceVersionEntity> objects) {
    return putAllByIndex(r'provinceCode', objects);
  }

  List<Id> putAllByProvinceCodeSync(
      List<AppPublicInstitutionProvinceVersionEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'provinceCode', objects, saveLinks: saveLinks);
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryWhereSort
    on QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
        AppPublicInstitutionProvinceVersionEntity, QWhere> {
  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryWhere on QueryBuilder<
    AppPublicInstitutionProvinceVersionEntity,
    AppPublicInstitutionProvinceVersionEntity,
    QWhereClause> {
  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterWhereClause> provinceCodeEqualTo(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'provinceCode',
        value: [provinceCode],
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterWhereClause> provinceCodeNotEqualTo(String provinceCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [],
              upper: [provinceCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [provinceCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [provinceCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'provinceCode',
              lower: [],
              upper: [provinceCode],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryFilter on QueryBuilder<
    AppPublicInstitutionProvinceVersionEntity,
    AppPublicInstitutionProvinceVersionEntity,
    QFilterCondition> {
  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'provinceCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
          AppPublicInstitutionProvinceVersionEntity, QAfterFilterCondition>
      provinceCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'provinceCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
          AppPublicInstitutionProvinceVersionEntity, QAfterFilterCondition>
      provinceCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'provinceCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'provinceCode',
        value: '',
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> provinceCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'provinceCode',
        value: '',
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtMillis',
        value: value,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
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

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
          AppPublicInstitutionProvinceVersionEntity, QAfterFilterCondition>
      versionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
          AppPublicInstitutionProvinceVersionEntity, QAfterFilterCondition>
      versionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'version',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: '',
      ));
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterFilterCondition> versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'version',
        value: '',
      ));
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryObject on QueryBuilder<
    AppPublicInstitutionProvinceVersionEntity,
    AppPublicInstitutionProvinceVersionEntity,
    QFilterCondition> {}

extension AppPublicInstitutionProvinceVersionEntityQueryLinks on QueryBuilder<
    AppPublicInstitutionProvinceVersionEntity,
    AppPublicInstitutionProvinceVersionEntity,
    QFilterCondition> {}

extension AppPublicInstitutionProvinceVersionEntityQuerySortBy on QueryBuilder<
    AppPublicInstitutionProvinceVersionEntity,
    AppPublicInstitutionProvinceVersionEntity,
    QSortBy> {
  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> sortByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> sortByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.desc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQuerySortThenBy
    on QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
        AppPublicInstitutionProvinceVersionEntity, QSortThenBy> {
  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> thenByProvinceCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> thenByProvinceCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'provinceCode', Sort.desc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryWhereDistinct
    on QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
        AppPublicInstitutionProvinceVersionEntity, QDistinct> {
  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QDistinct> distinctByProvinceCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'provinceCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QDistinct> distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }

  QueryBuilder<
      AppPublicInstitutionProvinceVersionEntity,
      AppPublicInstitutionProvinceVersionEntity,
      QDistinct> distinctByVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version', caseSensitive: caseSensitive);
    });
  }
}

extension AppPublicInstitutionProvinceVersionEntityQueryProperty
    on QueryBuilder<AppPublicInstitutionProvinceVersionEntity,
        AppPublicInstitutionProvinceVersionEntity, QQueryProperty> {
  QueryBuilder<AppPublicInstitutionProvinceVersionEntity, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity, String,
      QQueryOperations> provinceCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'provinceCode');
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity, int, QQueryOperations>
      updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }

  QueryBuilder<AppPublicInstitutionProvinceVersionEntity, String,
      QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
