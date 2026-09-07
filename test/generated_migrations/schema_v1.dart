// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class Categories extends Table with TableInfo<Categories, CategoriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> labelAr = GeneratedColumn<String>(
      'label_ar', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  @override
  List<GeneratedColumn> get $columns =>
      [key, labelAr, iconName, sortOrder, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CategoriesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriesData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      labelAr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label_ar'])!,
      iconName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_name'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }
}

class CategoriesData extends DataClass implements Insertable<CategoriesData> {
  final String key;
  final String labelAr;
  final String iconName;
  final int sortOrder;
  final bool archived;
  const CategoriesData(
      {required this.key,
      required this.labelAr,
      required this.iconName,
      required this.sortOrder,
      required this.archived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['label_ar'] = Variable<String>(labelAr);
    map['icon_name'] = Variable<String>(iconName);
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      key: Value(key),
      labelAr: Value(labelAr),
      iconName: Value(iconName),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
    );
  }

  factory CategoriesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriesData(
      key: serializer.fromJson<String>(json['key']),
      labelAr: serializer.fromJson<String>(json['labelAr']),
      iconName: serializer.fromJson<String>(json['iconName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'labelAr': serializer.toJson<String>(labelAr),
      'iconName': serializer.toJson<String>(iconName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  CategoriesData copyWith(
          {String? key,
          String? labelAr,
          String? iconName,
          int? sortOrder,
          bool? archived}) =>
      CategoriesData(
        key: key ?? this.key,
        labelAr: labelAr ?? this.labelAr,
        iconName: iconName ?? this.iconName,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
      );
  CategoriesData copyWithCompanion(CategoriesCompanion data) {
    return CategoriesData(
      key: data.key.present ? data.key.value : this.key,
      labelAr: data.labelAr.present ? data.labelAr.value : this.labelAr,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesData(')
          ..write('key: $key, ')
          ..write('labelAr: $labelAr, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, labelAr, iconName, sortOrder, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriesData &&
          other.key == this.key &&
          other.labelAr == this.labelAr &&
          other.iconName == this.iconName &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class CategoriesCompanion extends UpdateCompanion<CategoriesData> {
  final Value<String> key;
  final Value<String> labelAr;
  final Value<String> iconName;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.key = const Value.absent(),
    this.labelAr = const Value.absent(),
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String key,
    required String labelAr,
    required String iconName,
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        labelAr = Value(labelAr),
        iconName = Value(iconName);
  static Insertable<CategoriesData> custom({
    Expression<String>? key,
    Expression<String>? labelAr,
    Expression<String>? iconName,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (labelAr != null) 'label_ar': labelAr,
      if (iconName != null) 'icon_name': iconName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith(
      {Value<String>? key,
      Value<String>? labelAr,
      Value<String>? iconName,
      Value<int>? sortOrder,
      Value<bool>? archived,
      Value<int>? rowid}) {
    return CategoriesCompanion(
      key: key ?? this.key,
      labelAr: labelAr ?? this.labelAr,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (labelAr.present) {
      map['label_ar'] = Variable<String>(labelAr.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('key: $key, ')
          ..write('labelAr: $labelAr, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Items extends Table with TableInfo<Items, ItemsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Items(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> nameAr = GeneratedColumn<String>(
      'name_ar', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
      'name_en', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
      'category_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES categories ("key")'));
  late final GeneratedColumn<int> defaultAmountPiastres = GeneratedColumn<int>(
      'default_amount_piastres', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
      'use_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
      'last_used_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        nameAr,
        nameEn,
        categoryKey,
        defaultAmountPiastres,
        barcode,
        useCount,
        lastUsedAt,
        archived
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemsData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      nameAr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_ar'])!,
      nameEn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_en'])!,
      categoryKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_key'])!,
      defaultAmountPiastres: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}default_amount_piastres']),
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      useCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}use_count'])!,
      lastUsedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_used_at']),
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
    );
  }

  @override
  Items createAlias(String alias) {
    return Items(attachedDatabase, alias);
  }
}

class ItemsData extends DataClass implements Insertable<ItemsData> {
  final String id;
  final String nameAr;
  final String nameEn;
  final String categoryKey;
  final int? defaultAmountPiastres;
  final String? barcode;
  final int useCount;
  final DateTime? lastUsedAt;
  final bool archived;
  const ItemsData(
      {required this.id,
      required this.nameAr,
      required this.nameEn,
      required this.categoryKey,
      this.defaultAmountPiastres,
      this.barcode,
      required this.useCount,
      this.lastUsedAt,
      required this.archived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_ar'] = Variable<String>(nameAr);
    map['name_en'] = Variable<String>(nameEn);
    map['category_key'] = Variable<String>(categoryKey);
    if (!nullToAbsent || defaultAmountPiastres != null) {
      map['default_amount_piastres'] = Variable<int>(defaultAmountPiastres);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['use_count'] = Variable<int>(useCount);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      nameAr: Value(nameAr),
      nameEn: Value(nameEn),
      categoryKey: Value(categoryKey),
      defaultAmountPiastres: defaultAmountPiastres == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAmountPiastres),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      useCount: Value(useCount),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      archived: Value(archived),
    );
  }

  factory ItemsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemsData(
      id: serializer.fromJson<String>(json['id']),
      nameAr: serializer.fromJson<String>(json['nameAr']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      defaultAmountPiastres:
          serializer.fromJson<int?>(json['defaultAmountPiastres']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      useCount: serializer.fromJson<int>(json['useCount']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nameAr': serializer.toJson<String>(nameAr),
      'nameEn': serializer.toJson<String>(nameEn),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'defaultAmountPiastres': serializer.toJson<int?>(defaultAmountPiastres),
      'barcode': serializer.toJson<String?>(barcode),
      'useCount': serializer.toJson<int>(useCount),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  ItemsData copyWith(
          {String? id,
          String? nameAr,
          String? nameEn,
          String? categoryKey,
          Value<int?> defaultAmountPiastres = const Value.absent(),
          Value<String?> barcode = const Value.absent(),
          int? useCount,
          Value<DateTime?> lastUsedAt = const Value.absent(),
          bool? archived}) =>
      ItemsData(
        id: id ?? this.id,
        nameAr: nameAr ?? this.nameAr,
        nameEn: nameEn ?? this.nameEn,
        categoryKey: categoryKey ?? this.categoryKey,
        defaultAmountPiastres: defaultAmountPiastres.present
            ? defaultAmountPiastres.value
            : this.defaultAmountPiastres,
        barcode: barcode.present ? barcode.value : this.barcode,
        useCount: useCount ?? this.useCount,
        lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
        archived: archived ?? this.archived,
      );
  ItemsData copyWithCompanion(ItemsCompanion data) {
    return ItemsData(
      id: data.id.present ? data.id.value : this.id,
      nameAr: data.nameAr.present ? data.nameAr.value : this.nameAr,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      categoryKey:
          data.categoryKey.present ? data.categoryKey.value : this.categoryKey,
      defaultAmountPiastres: data.defaultAmountPiastres.present
          ? data.defaultAmountPiastres.value
          : this.defaultAmountPiastres,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
      lastUsedAt:
          data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemsData(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('nameEn: $nameEn, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('defaultAmountPiastres: $defaultAmountPiastres, ')
          ..write('barcode: $barcode, ')
          ..write('useCount: $useCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nameAr, nameEn, categoryKey,
      defaultAmountPiastres, barcode, useCount, lastUsedAt, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemsData &&
          other.id == this.id &&
          other.nameAr == this.nameAr &&
          other.nameEn == this.nameEn &&
          other.categoryKey == this.categoryKey &&
          other.defaultAmountPiastres == this.defaultAmountPiastres &&
          other.barcode == this.barcode &&
          other.useCount == this.useCount &&
          other.lastUsedAt == this.lastUsedAt &&
          other.archived == this.archived);
}

class ItemsCompanion extends UpdateCompanion<ItemsData> {
  final Value<String> id;
  final Value<String> nameAr;
  final Value<String> nameEn;
  final Value<String> categoryKey;
  final Value<int?> defaultAmountPiastres;
  final Value<String?> barcode;
  final Value<int> useCount;
  final Value<DateTime?> lastUsedAt;
  final Value<bool> archived;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.nameAr = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.defaultAmountPiastres = const Value.absent(),
    this.barcode = const Value.absent(),
    this.useCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String nameAr,
    required String nameEn,
    required String categoryKey,
    this.defaultAmountPiastres = const Value.absent(),
    this.barcode = const Value.absent(),
    this.useCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        nameAr = Value(nameAr),
        nameEn = Value(nameEn),
        categoryKey = Value(categoryKey);
  static Insertable<ItemsData> custom({
    Expression<String>? id,
    Expression<String>? nameAr,
    Expression<String>? nameEn,
    Expression<String>? categoryKey,
    Expression<int>? defaultAmountPiastres,
    Expression<String>? barcode,
    Expression<int>? useCount,
    Expression<DateTime>? lastUsedAt,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameAr != null) 'name_ar': nameAr,
      if (nameEn != null) 'name_en': nameEn,
      if (categoryKey != null) 'category_key': categoryKey,
      if (defaultAmountPiastres != null)
        'default_amount_piastres': defaultAmountPiastres,
      if (barcode != null) 'barcode': barcode,
      if (useCount != null) 'use_count': useCount,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? nameAr,
      Value<String>? nameEn,
      Value<String>? categoryKey,
      Value<int?>? defaultAmountPiastres,
      Value<String?>? barcode,
      Value<int>? useCount,
      Value<DateTime?>? lastUsedAt,
      Value<bool>? archived,
      Value<int>? rowid}) {
    return ItemsCompanion(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      categoryKey: categoryKey ?? this.categoryKey,
      defaultAmountPiastres:
          defaultAmountPiastres ?? this.defaultAmountPiastres,
      barcode: barcode ?? this.barcode,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nameAr.present) {
      map['name_ar'] = Variable<String>(nameAr.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (defaultAmountPiastres.present) {
      map['default_amount_piastres'] =
          Variable<int>(defaultAmountPiastres.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('nameEn: $nameEn, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('defaultAmountPiastres: $defaultAmountPiastres, ')
          ..write('barcode: $barcode, ')
          ..write('useCount: $useCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Entries extends Table with TableInfo<Entries, EntriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Entries(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
      'amount_piastres', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
      'category_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES categories ("key")'));
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('\'\''));
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('\'Cash\''));
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
      'photo_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('\'manual\''));
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        date,
        amountPiastres,
        categoryKey,
        itemId,
        description,
        paymentMethod,
        photoPath,
        source,
        note,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntriesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntriesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      amountPiastres: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_piastres'])!,
      categoryKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_key'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method'])!,
      photoPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_path']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  Entries createAlias(String alias) {
    return Entries(attachedDatabase, alias);
  }
}

class EntriesData extends DataClass implements Insertable<EntriesData> {
  final String id;
  final String date;
  final int amountPiastres;
  final String categoryKey;
  final String? itemId;
  final String description;
  final String paymentMethod;
  final String? photoPath;
  final String source;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EntriesData(
      {required this.id,
      required this.date,
      required this.amountPiastres,
      required this.categoryKey,
      this.itemId,
      required this.description,
      required this.paymentMethod,
      this.photoPath,
      required this.source,
      this.note,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['amount_piastres'] = Variable<int>(amountPiastres);
    map['category_key'] = Variable<String>(categoryKey);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['description'] = Variable<String>(description);
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      date: Value(date),
      amountPiastres: Value(amountPiastres),
      categoryKey: Value(categoryKey),
      itemId:
          itemId == null && nullToAbsent ? const Value.absent() : Value(itemId),
      description: Value(description),
      paymentMethod: Value(paymentMethod),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      source: Value(source),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EntriesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntriesData(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      amountPiastres: serializer.fromJson<int>(json['amountPiastres']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      description: serializer.fromJson<String>(json['description']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      source: serializer.fromJson<String>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'amountPiastres': serializer.toJson<int>(amountPiastres),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'itemId': serializer.toJson<String?>(itemId),
      'description': serializer.toJson<String>(description),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'photoPath': serializer.toJson<String?>(photoPath),
      'source': serializer.toJson<String>(source),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EntriesData copyWith(
          {String? id,
          String? date,
          int? amountPiastres,
          String? categoryKey,
          Value<String?> itemId = const Value.absent(),
          String? description,
          String? paymentMethod,
          Value<String?> photoPath = const Value.absent(),
          String? source,
          Value<String?> note = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      EntriesData(
        id: id ?? this.id,
        date: date ?? this.date,
        amountPiastres: amountPiastres ?? this.amountPiastres,
        categoryKey: categoryKey ?? this.categoryKey,
        itemId: itemId.present ? itemId.value : this.itemId,
        description: description ?? this.description,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        photoPath: photoPath.present ? photoPath.value : this.photoPath,
        source: source ?? this.source,
        note: note.present ? note.value : this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  EntriesData copyWithCompanion(EntriesCompanion data) {
    return EntriesData(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      amountPiastres: data.amountPiastres.present
          ? data.amountPiastres.value
          : this.amountPiastres,
      categoryKey:
          data.categoryKey.present ? data.categoryKey.value : this.categoryKey,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      description:
          data.description.present ? data.description.value : this.description,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntriesData(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('itemId: $itemId, ')
          ..write('description: $description, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('photoPath: $photoPath, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      date,
      amountPiastres,
      categoryKey,
      itemId,
      description,
      paymentMethod,
      photoPath,
      source,
      note,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntriesData &&
          other.id == this.id &&
          other.date == this.date &&
          other.amountPiastres == this.amountPiastres &&
          other.categoryKey == this.categoryKey &&
          other.itemId == this.itemId &&
          other.description == this.description &&
          other.paymentMethod == this.paymentMethod &&
          other.photoPath == this.photoPath &&
          other.source == this.source &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EntriesCompanion extends UpdateCompanion<EntriesData> {
  final Value<String> id;
  final Value<String> date;
  final Value<int> amountPiastres;
  final Value<String> categoryKey;
  final Value<String?> itemId;
  final Value<String> description;
  final Value<String> paymentMethod;
  final Value<String?> photoPath;
  final Value<String> source;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.amountPiastres = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.itemId = const Value.absent(),
    this.description = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String date,
    required int amountPiastres,
    required String categoryKey,
    this.itemId = const Value.absent(),
    this.description = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        date = Value(date),
        amountPiastres = Value(amountPiastres),
        categoryKey = Value(categoryKey),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<EntriesData> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<int>? amountPiastres,
    Expression<String>? categoryKey,
    Expression<String>? itemId,
    Expression<String>? description,
    Expression<String>? paymentMethod,
    Expression<String>? photoPath,
    Expression<String>? source,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (amountPiastres != null) 'amount_piastres': amountPiastres,
      if (categoryKey != null) 'category_key': categoryKey,
      if (itemId != null) 'item_id': itemId,
      if (description != null) 'description': description,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (photoPath != null) 'photo_path': photoPath,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? date,
      Value<int>? amountPiastres,
      Value<String>? categoryKey,
      Value<String?>? itemId,
      Value<String>? description,
      Value<String>? paymentMethod,
      Value<String?>? photoPath,
      Value<String>? source,
      Value<String?>? note,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return EntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      amountPiastres: amountPiastres ?? this.amountPiastres,
      categoryKey: categoryKey ?? this.categoryKey,
      itemId: itemId ?? this.itemId,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      photoPath: photoPath ?? this.photoPath,
      source: source ?? this.source,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountPiastres.present) {
      map['amount_piastres'] = Variable<int>(amountPiastres.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('itemId: $itemId, ')
          ..write('description: $description, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('photoPath: $photoPath, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SalaryPeriods extends Table
    with TableInfo<SalaryPeriods, SalaryPeriodsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SalaryPeriods(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> datePaid = GeneratedColumn<String>(
      'date_paid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
      'amount_piastres', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> evidencePhotoPath =
      GeneratedColumn<String>('evidence_photo_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, datePaid, amountPiastres, evidencePhotoPath, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'salary_periods';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalaryPeriodsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalaryPeriodsData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      datePaid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_paid'])!,
      amountPiastres: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_piastres'])!,
      evidencePhotoPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}evidence_photo_path']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  SalaryPeriods createAlias(String alias) {
    return SalaryPeriods(attachedDatabase, alias);
  }
}

class SalaryPeriodsData extends DataClass
    implements Insertable<SalaryPeriodsData> {
  final String id;
  final String datePaid;
  final int amountPiastres;
  final String? evidencePhotoPath;
  final String? note;
  const SalaryPeriodsData(
      {required this.id,
      required this.datePaid,
      required this.amountPiastres,
      this.evidencePhotoPath,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date_paid'] = Variable<String>(datePaid);
    map['amount_piastres'] = Variable<int>(amountPiastres);
    if (!nullToAbsent || evidencePhotoPath != null) {
      map['evidence_photo_path'] = Variable<String>(evidencePhotoPath);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SalaryPeriodsCompanion toCompanion(bool nullToAbsent) {
    return SalaryPeriodsCompanion(
      id: Value(id),
      datePaid: Value(datePaid),
      amountPiastres: Value(amountPiastres),
      evidencePhotoPath: evidencePhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(evidencePhotoPath),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SalaryPeriodsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalaryPeriodsData(
      id: serializer.fromJson<String>(json['id']),
      datePaid: serializer.fromJson<String>(json['datePaid']),
      amountPiastres: serializer.fromJson<int>(json['amountPiastres']),
      evidencePhotoPath:
          serializer.fromJson<String?>(json['evidencePhotoPath']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'datePaid': serializer.toJson<String>(datePaid),
      'amountPiastres': serializer.toJson<int>(amountPiastres),
      'evidencePhotoPath': serializer.toJson<String?>(evidencePhotoPath),
      'note': serializer.toJson<String?>(note),
    };
  }

  SalaryPeriodsData copyWith(
          {String? id,
          String? datePaid,
          int? amountPiastres,
          Value<String?> evidencePhotoPath = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      SalaryPeriodsData(
        id: id ?? this.id,
        datePaid: datePaid ?? this.datePaid,
        amountPiastres: amountPiastres ?? this.amountPiastres,
        evidencePhotoPath: evidencePhotoPath.present
            ? evidencePhotoPath.value
            : this.evidencePhotoPath,
        note: note.present ? note.value : this.note,
      );
  SalaryPeriodsData copyWithCompanion(SalaryPeriodsCompanion data) {
    return SalaryPeriodsData(
      id: data.id.present ? data.id.value : this.id,
      datePaid: data.datePaid.present ? data.datePaid.value : this.datePaid,
      amountPiastres: data.amountPiastres.present
          ? data.amountPiastres.value
          : this.amountPiastres,
      evidencePhotoPath: data.evidencePhotoPath.present
          ? data.evidencePhotoPath.value
          : this.evidencePhotoPath,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalaryPeriodsData(')
          ..write('id: $id, ')
          ..write('datePaid: $datePaid, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('evidencePhotoPath: $evidencePhotoPath, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, datePaid, amountPiastres, evidencePhotoPath, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalaryPeriodsData &&
          other.id == this.id &&
          other.datePaid == this.datePaid &&
          other.amountPiastres == this.amountPiastres &&
          other.evidencePhotoPath == this.evidencePhotoPath &&
          other.note == this.note);
}

class SalaryPeriodsCompanion extends UpdateCompanion<SalaryPeriodsData> {
  final Value<String> id;
  final Value<String> datePaid;
  final Value<int> amountPiastres;
  final Value<String?> evidencePhotoPath;
  final Value<String?> note;
  final Value<int> rowid;
  const SalaryPeriodsCompanion({
    this.id = const Value.absent(),
    this.datePaid = const Value.absent(),
    this.amountPiastres = const Value.absent(),
    this.evidencePhotoPath = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalaryPeriodsCompanion.insert({
    required String id,
    required String datePaid,
    required int amountPiastres,
    this.evidencePhotoPath = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        datePaid = Value(datePaid),
        amountPiastres = Value(amountPiastres);
  static Insertable<SalaryPeriodsData> custom({
    Expression<String>? id,
    Expression<String>? datePaid,
    Expression<int>? amountPiastres,
    Expression<String>? evidencePhotoPath,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datePaid != null) 'date_paid': datePaid,
      if (amountPiastres != null) 'amount_piastres': amountPiastres,
      if (evidencePhotoPath != null) 'evidence_photo_path': evidencePhotoPath,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalaryPeriodsCompanion copyWith(
      {Value<String>? id,
      Value<String>? datePaid,
      Value<int>? amountPiastres,
      Value<String?>? evidencePhotoPath,
      Value<String?>? note,
      Value<int>? rowid}) {
    return SalaryPeriodsCompanion(
      id: id ?? this.id,
      datePaid: datePaid ?? this.datePaid,
      amountPiastres: amountPiastres ?? this.amountPiastres,
      evidencePhotoPath: evidencePhotoPath ?? this.evidencePhotoPath,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (datePaid.present) {
      map['date_paid'] = Variable<String>(datePaid.value);
    }
    if (amountPiastres.present) {
      map['amount_piastres'] = Variable<int>(amountPiastres.value);
    }
    if (evidencePhotoPath.present) {
      map['evidence_photo_path'] = Variable<String>(evidencePhotoPath.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalaryPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('datePaid: $datePaid, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('evidencePhotoPath: $evidencePhotoPath, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV1 extends GeneratedDatabase {
  DatabaseAtV1(QueryExecutor e) : super(e);
  late final Categories categories = Categories(this);
  late final Items items = Items(this);
  late final Entries entries = Entries(this);
  late final SalaryPeriods salaryPeriods = SalaryPeriods(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [categories, items, entries, salaryPeriods];
  @override
  int get schemaVersion => 1;
}
