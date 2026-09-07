// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelArMeta =
      const VerificationMeta('labelAr');
  @override
  late final GeneratedColumn<String> labelAr = GeneratedColumn<String>(
      'label_ar', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconNameMeta =
      const VerificationMeta('iconName');
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
      'icon_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [key, labelAr, iconName, sortOrder, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('label_ar')) {
      context.handle(_labelArMeta,
          labelAr.isAcceptableOrUnknown(data['label_ar']!, _labelArMeta));
    } else if (isInserting) {
      context.missing(_labelArMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(_iconNameMeta,
          iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta));
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
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
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String key;
  final String labelAr;
  final String iconName;
  final int sortOrder;
  final bool archived;
  const Category(
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

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
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

  Category copyWith(
          {String? key,
          String? labelAr,
          String? iconName,
          int? sortOrder,
          bool? archived}) =>
      Category(
        key: key ?? this.key,
        labelAr: labelAr ?? this.labelAr,
        iconName: iconName ?? this.iconName,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      key: data.key.present ? data.key.value : this.key,
      labelAr: data.labelAr.present ? data.labelAr.value : this.labelAr,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
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
      (other is Category &&
          other.key == this.key &&
          other.labelAr == this.labelAr &&
          other.iconName == this.iconName &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
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
  static Insertable<Category> custom({
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

class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameArMeta = const VerificationMeta('nameAr');
  @override
  late final GeneratedColumn<String> nameAr = GeneratedColumn<String>(
      'name_ar', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
      'name_en', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryKeyMeta =
      const VerificationMeta('categoryKey');
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
      'category_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES categories ("key")'));
  static const VerificationMeta _defaultAmountPiastresMeta =
      const VerificationMeta('defaultAmountPiastres');
  @override
  late final GeneratedColumn<int> defaultAmountPiastres = GeneratedColumn<int>(
      'default_amount_piastres', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _useCountMeta =
      const VerificationMeta('useCount');
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
      'use_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastUsedAtMeta =
      const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
      'last_used_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
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
  VerificationContext validateIntegrity(Insertable<Item> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_ar')) {
      context.handle(_nameArMeta,
          nameAr.isAcceptableOrUnknown(data['name_ar']!, _nameArMeta));
    } else if (isInserting) {
      context.missing(_nameArMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(_nameEnMeta,
          nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta));
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
          _categoryKeyMeta,
          categoryKey.isAcceptableOrUnknown(
              data['category_key']!, _categoryKeyMeta));
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('default_amount_piastres')) {
      context.handle(
          _defaultAmountPiastresMeta,
          defaultAmountPiastres.isAcceptableOrUnknown(
              data['default_amount_piastres']!, _defaultAmountPiastresMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('use_count')) {
      context.handle(_useCountMeta,
          useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta));
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
          _lastUsedAtMeta,
          lastUsedAt.isAcceptableOrUnknown(
              data['last_used_at']!, _lastUsedAtMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
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
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final String nameAr;
  final String nameEn;
  final String categoryKey;
  final int? defaultAmountPiastres;
  final String? barcode;
  final int useCount;
  final DateTime? lastUsedAt;
  final bool archived;
  const Item(
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

  factory Item.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
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

  Item copyWith(
          {String? id,
          String? nameAr,
          String? nameEn,
          String? categoryKey,
          Value<int?> defaultAmountPiastres = const Value.absent(),
          Value<String?> barcode = const Value.absent(),
          int? useCount,
          Value<DateTime?> lastUsedAt = const Value.absent(),
          bool? archived}) =>
      Item(
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
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
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
    return (StringBuffer('Item(')
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
      (other is Item &&
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

class ItemsCompanion extends UpdateCompanion<Item> {
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
  static Insertable<Item> custom({
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

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountPiastresMeta =
      const VerificationMeta('amountPiastres');
  @override
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
      'amount_piastres', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryKeyMeta =
      const VerificationMeta('categoryKey');
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
      'category_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES categories ("key")'));
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Cash'));
  static const VerificationMeta _photoPathMeta =
      const VerificationMeta('photoPath');
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
      'photo_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
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
  VerificationContext validateIntegrity(Insertable<Entry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_piastres')) {
      context.handle(
          _amountPiastresMeta,
          amountPiastres.isAcceptableOrUnknown(
              data['amount_piastres']!, _amountPiastresMeta));
    } else if (isInserting) {
      context.missing(_amountPiastresMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
          _categoryKeyMeta,
          categoryKey.isAcceptableOrUnknown(
              data['category_key']!, _categoryKeyMeta));
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    }
    if (data.containsKey('photo_path')) {
      context.handle(_photoPathMeta,
          photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
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
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
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
  const Entry(
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

  factory Entry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
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

  Entry copyWith(
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
      Entry(
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
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
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
    return (StringBuffer('Entry(')
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
      (other is Entry &&
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

class EntriesCompanion extends UpdateCompanion<Entry> {
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
  static Insertable<Entry> custom({
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

class $SalaryPeriodsTable extends SalaryPeriods
    with TableInfo<$SalaryPeriodsTable, SalaryPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalaryPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _datePaidMeta =
      const VerificationMeta('datePaid');
  @override
  late final GeneratedColumn<String> datePaid = GeneratedColumn<String>(
      'date_paid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountPiastresMeta =
      const VerificationMeta('amountPiastres');
  @override
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
      'amount_piastres', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _evidencePhotoPathMeta =
      const VerificationMeta('evidencePhotoPath');
  @override
  late final GeneratedColumn<String> evidencePhotoPath =
      GeneratedColumn<String>('evidence_photo_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
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
  VerificationContext validateIntegrity(Insertable<SalaryPeriod> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date_paid')) {
      context.handle(_datePaidMeta,
          datePaid.isAcceptableOrUnknown(data['date_paid']!, _datePaidMeta));
    } else if (isInserting) {
      context.missing(_datePaidMeta);
    }
    if (data.containsKey('amount_piastres')) {
      context.handle(
          _amountPiastresMeta,
          amountPiastres.isAcceptableOrUnknown(
              data['amount_piastres']!, _amountPiastresMeta));
    } else if (isInserting) {
      context.missing(_amountPiastresMeta);
    }
    if (data.containsKey('evidence_photo_path')) {
      context.handle(
          _evidencePhotoPathMeta,
          evidencePhotoPath.isAcceptableOrUnknown(
              data['evidence_photo_path']!, _evidencePhotoPathMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalaryPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalaryPeriod(
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
  $SalaryPeriodsTable createAlias(String alias) {
    return $SalaryPeriodsTable(attachedDatabase, alias);
  }
}

class SalaryPeriod extends DataClass implements Insertable<SalaryPeriod> {
  final String id;
  final String datePaid;
  final int amountPiastres;
  final String? evidencePhotoPath;
  final String? note;
  const SalaryPeriod(
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

  factory SalaryPeriod.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalaryPeriod(
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

  SalaryPeriod copyWith(
          {String? id,
          String? datePaid,
          int? amountPiastres,
          Value<String?> evidencePhotoPath = const Value.absent(),
          Value<String?> note = const Value.absent()}) =>
      SalaryPeriod(
        id: id ?? this.id,
        datePaid: datePaid ?? this.datePaid,
        amountPiastres: amountPiastres ?? this.amountPiastres,
        evidencePhotoPath: evidencePhotoPath.present
            ? evidencePhotoPath.value
            : this.evidencePhotoPath,
        note: note.present ? note.value : this.note,
      );
  SalaryPeriod copyWithCompanion(SalaryPeriodsCompanion data) {
    return SalaryPeriod(
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
    return (StringBuffer('SalaryPeriod(')
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
      (other is SalaryPeriod &&
          other.id == this.id &&
          other.datePaid == this.datePaid &&
          other.amountPiastres == this.amountPiastres &&
          other.evidencePhotoPath == this.evidencePhotoPath &&
          other.note == this.note);
}

class SalaryPeriodsCompanion extends UpdateCompanion<SalaryPeriod> {
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
  static Insertable<SalaryPeriod> custom({
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $SalaryPeriodsTable salaryPeriods = $SalaryPeriodsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [categories, items, entries, salaryPeriods];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String key,
  required String labelAr,
  required String iconName,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> key,
  Value<String> labelAr,
  Value<String> iconName,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.items,
          aliasName:
              $_aliasNameGenerator(db.categories.key, db.items.categoryKey));

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager($_db, $_db.items)
        .filter((f) => f.categoryKey.key($_item.key));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.entries,
          aliasName:
              $_aliasNameGenerator(db.categories.key, db.entries.categoryKey));

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager($_db, $_db.entries)
        .filter((f) => f.categoryKey.key($_item.key));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get labelAr => $composableBuilder(
      column: $table.labelAr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  Expression<bool> itemsRefs(
      Expression<bool> Function($$ItemsTableFilterComposer f) f) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.key,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.categoryKey,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableFilterComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> entriesRefs(
      Expression<bool> Function($$EntriesTableFilterComposer f) f) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.key,
        referencedTable: $db.entries,
        getReferencedColumn: (t) => t.categoryKey,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EntriesTableFilterComposer(
              $db: $db,
              $table: $db.entries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get labelAr => $composableBuilder(
      column: $table.labelAr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconName => $composableBuilder(
      column: $table.iconName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get labelAr =>
      $composableBuilder(column: $table.labelAr, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> itemsRefs<T extends Object>(
      Expression<T> Function($$ItemsTableAnnotationComposer a) f) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.key,
        referencedTable: $db.items,
        getReferencedColumn: (t) => t.categoryKey,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.items,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> entriesRefs<T extends Object>(
      Expression<T> Function($$EntriesTableAnnotationComposer a) f) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.key,
        referencedTable: $db.entries,
        getReferencedColumn: (t) => t.categoryKey,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.entries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function({bool itemsRefs, bool entriesRefs})> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> labelAr = const Value.absent(),
            Value<String> iconName = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion(
            key: key,
            labelAr: labelAr,
            iconName: iconName,
            sortOrder: sortOrder,
            archived: archived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String labelAr,
            required String iconName,
            Value<int> sortOrder = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CategoriesCompanion.insert(
            key: key,
            labelAr: labelAr,
            iconName: iconName,
            sortOrder: sortOrder,
            archived: archived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({itemsRefs = false, entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itemsRefs) db.items,
                if (entriesRefs) db.entries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemsRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$CategoriesTableReferences._itemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .itemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryKey == item.key),
                        typedResults: items),
                  if (entriesRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable:
                            $$CategoriesTableReferences._entriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CategoriesTableReferences(db, table, p0)
                                .entriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryKey == item.key),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, $$CategoriesTableReferences),
    Category,
    PrefetchHooks Function({bool itemsRefs, bool entriesRefs})>;
typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String id,
  required String nameAr,
  required String nameEn,
  required String categoryKey,
  Value<int?> defaultAmountPiastres,
  Value<String?> barcode,
  Value<int> useCount,
  Value<DateTime?> lastUsedAt,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> id,
  Value<String> nameAr,
  Value<String> nameEn,
  Value<String> categoryKey,
  Value<int?> defaultAmountPiastres,
  Value<String?> barcode,
  Value<int> useCount,
  Value<DateTime?> lastUsedAt,
  Value<bool> archived,
  Value<int> rowid,
});

final class $$ItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTable, Item> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryKeyTable(_$AppDatabase db) =>
      db.categories.createAlias(
          $_aliasNameGenerator(db.items.categoryKey, db.categories.key));

  $$CategoriesTableProcessedTableManager get categoryKey {
    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.key($_item.categoryKey));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameAr => $composableBuilder(
      column: $table.nameAr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nameEn => $composableBuilder(
      column: $table.nameEn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultAmountPiastres => $composableBuilder(
      column: $table.defaultAmountPiastres,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get useCount => $composableBuilder(
      column: $table.useCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameAr => $composableBuilder(
      column: $table.nameAr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nameEn => $composableBuilder(
      column: $table.nameEn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultAmountPiastres => $composableBuilder(
      column: $table.defaultAmountPiastres,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get useCount => $composableBuilder(
      column: $table.useCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameAr =>
      $composableBuilder(column: $table.nameAr, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<int> get defaultAmountPiastres => $composableBuilder(
      column: $table.defaultAmountPiastres, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemsTable,
    Item,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (Item, $$ItemsTableReferences),
    Item,
    PrefetchHooks Function({bool categoryKey})> {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> nameAr = const Value.absent(),
            Value<String> nameEn = const Value.absent(),
            Value<String> categoryKey = const Value.absent(),
            Value<int?> defaultAmountPiastres = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<int> useCount = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion(
            id: id,
            nameAr: nameAr,
            nameEn: nameEn,
            categoryKey: categoryKey,
            defaultAmountPiastres: defaultAmountPiastres,
            barcode: barcode,
            useCount: useCount,
            lastUsedAt: lastUsedAt,
            archived: archived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String nameAr,
            required String nameEn,
            required String categoryKey,
            Value<int?> defaultAmountPiastres = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<int> useCount = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion.insert(
            id: id,
            nameAr: nameAr,
            nameEn: nameEn,
            categoryKey: categoryKey,
            defaultAmountPiastres: defaultAmountPiastres,
            barcode: barcode,
            useCount: useCount,
            lastUsedAt: lastUsedAt,
            archived: archived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ItemsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({categoryKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryKey) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryKey,
                    referencedTable:
                        $$ItemsTableReferences._categoryKeyTable(db),
                    referencedColumn:
                        $$ItemsTableReferences._categoryKeyTable(db).key,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemsTable,
    Item,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (Item, $$ItemsTableReferences),
    Item,
    PrefetchHooks Function({bool categoryKey})>;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  required String id,
  required String date,
  required int amountPiastres,
  required String categoryKey,
  Value<String?> itemId,
  Value<String> description,
  Value<String> paymentMethod,
  Value<String?> photoPath,
  Value<String> source,
  Value<String?> note,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<String> id,
  Value<String> date,
  Value<int> amountPiastres,
  Value<String> categoryKey,
  Value<String?> itemId,
  Value<String> description,
  Value<String> paymentMethod,
  Value<String?> photoPath,
  Value<String> source,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryKeyTable(_$AppDatabase db) =>
      db.categories.createAlias(
          $_aliasNameGenerator(db.entries.categoryKey, db.categories.key));

  $$CategoriesTableProcessedTableManager get categoryKey {
    final manager = $$CategoriesTableTableManager($_db, $_db.categories)
        .filter((f) => f.key($_item.categoryKey));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoPath => $composableBuilder(
      column: $table.photoPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableFilterComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoPath => $composableBuilder(
      column: $table.photoPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryKey,
        referencedTable: $db.categories,
        getReferencedColumn: (t) => t.key,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.categories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EntriesTable,
    Entry,
    $$EntriesTableFilterComposer,
    $$EntriesTableOrderingComposer,
    $$EntriesTableAnnotationComposer,
    $$EntriesTableCreateCompanionBuilder,
    $$EntriesTableUpdateCompanionBuilder,
    (Entry, $$EntriesTableReferences),
    Entry,
    PrefetchHooks Function({bool categoryKey})> {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<int> amountPiastres = const Value.absent(),
            Value<String> categoryKey = const Value.absent(),
            Value<String?> itemId = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> paymentMethod = const Value.absent(),
            Value<String?> photoPath = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EntriesCompanion(
            id: id,
            date: date,
            amountPiastres: amountPiastres,
            categoryKey: categoryKey,
            itemId: itemId,
            description: description,
            paymentMethod: paymentMethod,
            photoPath: photoPath,
            source: source,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String date,
            required int amountPiastres,
            required String categoryKey,
            Value<String?> itemId = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> paymentMethod = const Value.absent(),
            Value<String?> photoPath = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EntriesCompanion.insert(
            id: id,
            date: date,
            amountPiastres: amountPiastres,
            categoryKey: categoryKey,
            itemId: itemId,
            description: description,
            paymentMethod: paymentMethod,
            photoPath: photoPath,
            source: source,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$EntriesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({categoryKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryKey) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryKey,
                    referencedTable:
                        $$EntriesTableReferences._categoryKeyTable(db),
                    referencedColumn:
                        $$EntriesTableReferences._categoryKeyTable(db).key,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$EntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EntriesTable,
    Entry,
    $$EntriesTableFilterComposer,
    $$EntriesTableOrderingComposer,
    $$EntriesTableAnnotationComposer,
    $$EntriesTableCreateCompanionBuilder,
    $$EntriesTableUpdateCompanionBuilder,
    (Entry, $$EntriesTableReferences),
    Entry,
    PrefetchHooks Function({bool categoryKey})>;
typedef $$SalaryPeriodsTableCreateCompanionBuilder = SalaryPeriodsCompanion
    Function({
  required String id,
  required String datePaid,
  required int amountPiastres,
  Value<String?> evidencePhotoPath,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$SalaryPeriodsTableUpdateCompanionBuilder = SalaryPeriodsCompanion
    Function({
  Value<String> id,
  Value<String> datePaid,
  Value<int> amountPiastres,
  Value<String?> evidencePhotoPath,
  Value<String?> note,
  Value<int> rowid,
});

class $$SalaryPeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $SalaryPeriodsTable> {
  $$SalaryPeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get datePaid => $composableBuilder(
      column: $table.datePaid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get evidencePhotoPath => $composableBuilder(
      column: $table.evidencePhotoPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$SalaryPeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $SalaryPeriodsTable> {
  $$SalaryPeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get datePaid => $composableBuilder(
      column: $table.datePaid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get evidencePhotoPath => $composableBuilder(
      column: $table.evidencePhotoPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$SalaryPeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalaryPeriodsTable> {
  $$SalaryPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datePaid =>
      $composableBuilder(column: $table.datePaid, builder: (column) => column);

  GeneratedColumn<int> get amountPiastres => $composableBuilder(
      column: $table.amountPiastres, builder: (column) => column);

  GeneratedColumn<String> get evidencePhotoPath => $composableBuilder(
      column: $table.evidencePhotoPath, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$SalaryPeriodsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SalaryPeriodsTable,
    SalaryPeriod,
    $$SalaryPeriodsTableFilterComposer,
    $$SalaryPeriodsTableOrderingComposer,
    $$SalaryPeriodsTableAnnotationComposer,
    $$SalaryPeriodsTableCreateCompanionBuilder,
    $$SalaryPeriodsTableUpdateCompanionBuilder,
    (
      SalaryPeriod,
      BaseReferences<_$AppDatabase, $SalaryPeriodsTable, SalaryPeriod>
    ),
    SalaryPeriod,
    PrefetchHooks Function()> {
  $$SalaryPeriodsTableTableManager(_$AppDatabase db, $SalaryPeriodsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalaryPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalaryPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalaryPeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> datePaid = const Value.absent(),
            Value<int> amountPiastres = const Value.absent(),
            Value<String?> evidencePhotoPath = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalaryPeriodsCompanion(
            id: id,
            datePaid: datePaid,
            amountPiastres: amountPiastres,
            evidencePhotoPath: evidencePhotoPath,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String datePaid,
            required int amountPiastres,
            Value<String?> evidencePhotoPath = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalaryPeriodsCompanion.insert(
            id: id,
            datePaid: datePaid,
            amountPiastres: amountPiastres,
            evidencePhotoPath: evidencePhotoPath,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SalaryPeriodsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SalaryPeriodsTable,
    SalaryPeriod,
    $$SalaryPeriodsTableFilterComposer,
    $$SalaryPeriodsTableOrderingComposer,
    $$SalaryPeriodsTableAnnotationComposer,
    $$SalaryPeriodsTableCreateCompanionBuilder,
    $$SalaryPeriodsTableUpdateCompanionBuilder,
    (
      SalaryPeriod,
      BaseReferences<_$AppDatabase, $SalaryPeriodsTable, SalaryPeriod>
    ),
    SalaryPeriod,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$SalaryPeriodsTableTableManager get salaryPeriods =>
      $$SalaryPeriodsTableTableManager(_db, _db.salaryPeriods);
}
