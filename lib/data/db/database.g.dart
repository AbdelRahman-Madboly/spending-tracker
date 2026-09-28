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
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelArMeta = const VerificationMeta(
    'labelAr',
  );
  @override
  late final GeneratedColumn<String> labelAr = GeneratedColumn<String>(
    'label_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorKeyMeta = const VerificationMeta(
    'colorKey',
  );
  @override
  late final GeneratedColumn<String> colorKey = GeneratedColumn<String>(
    'color_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    labelAr,
    iconName,
    colorKey,
    sortOrder,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('label_ar')) {
      context.handle(
        _labelArMeta,
        labelAr.isAcceptableOrUnknown(data['label_ar']!, _labelArMeta),
      );
    } else if (isInserting) {
      context.missing(_labelArMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('color_key')) {
      context.handle(
        _colorKeyMeta,
        colorKey.isAcceptableOrUnknown(data['color_key']!, _colorKeyMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      labelAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_ar'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      colorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_key'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
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

  /// One of the colour keys in spec §7.2 (`Drinks` ... `Other`). Added in
  /// v3 and backfilled there, so it is null only between the column being
  /// added and the backfill running; readers fall back to `Other`.
  final String? colorKey;
  final int sortOrder;
  final bool archived;
  const Category({
    required this.key,
    required this.labelAr,
    required this.iconName,
    this.colorKey,
    required this.sortOrder,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['label_ar'] = Variable<String>(labelAr);
    map['icon_name'] = Variable<String>(iconName);
    if (!nullToAbsent || colorKey != null) {
      map['color_key'] = Variable<String>(colorKey);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      key: Value(key),
      labelAr: Value(labelAr),
      iconName: Value(iconName),
      colorKey: colorKey == null && nullToAbsent
          ? const Value.absent()
          : Value(colorKey),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      key: serializer.fromJson<String>(json['key']),
      labelAr: serializer.fromJson<String>(json['labelAr']),
      iconName: serializer.fromJson<String>(json['iconName']),
      colorKey: serializer.fromJson<String?>(json['colorKey']),
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
      'colorKey': serializer.toJson<String?>(colorKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Category copyWith({
    String? key,
    String? labelAr,
    String? iconName,
    Value<String?> colorKey = const Value.absent(),
    int? sortOrder,
    bool? archived,
  }) => Category(
    key: key ?? this.key,
    labelAr: labelAr ?? this.labelAr,
    iconName: iconName ?? this.iconName,
    colorKey: colorKey.present ? colorKey.value : this.colorKey,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      key: data.key.present ? data.key.value : this.key,
      labelAr: data.labelAr.present ? data.labelAr.value : this.labelAr,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorKey: data.colorKey.present ? data.colorKey.value : this.colorKey,
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
          ..write('colorKey: $colorKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, labelAr, iconName, colorKey, sortOrder, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.key == this.key &&
          other.labelAr == this.labelAr &&
          other.iconName == this.iconName &&
          other.colorKey == this.colorKey &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> key;
  final Value<String> labelAr;
  final Value<String> iconName;
  final Value<String?> colorKey;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.key = const Value.absent(),
    this.labelAr = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String key,
    required String labelAr,
    required String iconName,
    this.colorKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       labelAr = Value(labelAr),
       iconName = Value(iconName);
  static Insertable<Category> custom({
    Expression<String>? key,
    Expression<String>? labelAr,
    Expression<String>? iconName,
    Expression<String>? colorKey,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (labelAr != null) 'label_ar': labelAr,
      if (iconName != null) 'icon_name': iconName,
      if (colorKey != null) 'color_key': colorKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? key,
    Value<String>? labelAr,
    Value<String>? iconName,
    Value<String?>? colorKey,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      key: key ?? this.key,
      labelAr: labelAr ?? this.labelAr,
      iconName: iconName ?? this.iconName,
      colorKey: colorKey ?? this.colorKey,
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
    if (colorKey.present) {
      map['color_key'] = Variable<String>(colorKey.value);
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
          ..write('colorKey: $colorKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubcategoriesTable extends Subcategories
    with TableInfo<$SubcategoriesTable, Subcategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubcategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories ("key")',
    ),
  );
  static const VerificationMeta _labelArMeta = const VerificationMeta(
    'labelAr',
  );
  @override
  late final GeneratedColumn<String> labelAr = GeneratedColumn<String>(
    'label_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    categoryKey,
    labelAr,
    iconName,
    sortOrder,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subcategories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subcategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('label_ar')) {
      context.handle(
        _labelArMeta,
        labelAr.isAcceptableOrUnknown(data['label_ar']!, _labelArMeta),
      );
    } else if (isInserting) {
      context.missing(_labelArMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Subcategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subcategory(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      labelAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_ar'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $SubcategoriesTable createAlias(String alias) {
    return $SubcategoriesTable(attachedDatabase, alias);
  }
}

class Subcategory extends DataClass implements Insertable<Subcategory> {
  final String key;
  final String categoryKey;
  final String labelAr;
  final String iconName;
  final int sortOrder;
  final bool archived;
  const Subcategory({
    required this.key,
    required this.categoryKey,
    required this.labelAr,
    required this.iconName,
    required this.sortOrder,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['category_key'] = Variable<String>(categoryKey);
    map['label_ar'] = Variable<String>(labelAr);
    map['icon_name'] = Variable<String>(iconName);
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  SubcategoriesCompanion toCompanion(bool nullToAbsent) {
    return SubcategoriesCompanion(
      key: Value(key),
      categoryKey: Value(categoryKey),
      labelAr: Value(labelAr),
      iconName: Value(iconName),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
    );
  }

  factory Subcategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subcategory(
      key: serializer.fromJson<String>(json['key']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
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
      'categoryKey': serializer.toJson<String>(categoryKey),
      'labelAr': serializer.toJson<String>(labelAr),
      'iconName': serializer.toJson<String>(iconName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Subcategory copyWith({
    String? key,
    String? categoryKey,
    String? labelAr,
    String? iconName,
    int? sortOrder,
    bool? archived,
  }) => Subcategory(
    key: key ?? this.key,
    categoryKey: categoryKey ?? this.categoryKey,
    labelAr: labelAr ?? this.labelAr,
    iconName: iconName ?? this.iconName,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
  );
  Subcategory copyWithCompanion(SubcategoriesCompanion data) {
    return Subcategory(
      key: data.key.present ? data.key.value : this.key,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      labelAr: data.labelAr.present ? data.labelAr.value : this.labelAr,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subcategory(')
          ..write('key: $key, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('labelAr: $labelAr, ')
          ..write('iconName: $iconName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, categoryKey, labelAr, iconName, sortOrder, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subcategory &&
          other.key == this.key &&
          other.categoryKey == this.categoryKey &&
          other.labelAr == this.labelAr &&
          other.iconName == this.iconName &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived);
}

class SubcategoriesCompanion extends UpdateCompanion<Subcategory> {
  final Value<String> key;
  final Value<String> categoryKey;
  final Value<String> labelAr;
  final Value<String> iconName;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> rowid;
  const SubcategoriesCompanion({
    this.key = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.labelAr = const Value.absent(),
    this.iconName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubcategoriesCompanion.insert({
    required String key,
    required String categoryKey,
    required String labelAr,
    required String iconName,
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       categoryKey = Value(categoryKey),
       labelAr = Value(labelAr),
       iconName = Value(iconName);
  static Insertable<Subcategory> custom({
    Expression<String>? key,
    Expression<String>? categoryKey,
    Expression<String>? labelAr,
    Expression<String>? iconName,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (categoryKey != null) 'category_key': categoryKey,
      if (labelAr != null) 'label_ar': labelAr,
      if (iconName != null) 'icon_name': iconName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubcategoriesCompanion copyWith({
    Value<String>? key,
    Value<String>? categoryKey,
    Value<String>? labelAr,
    Value<String>? iconName,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return SubcategoriesCompanion(
      key: key ?? this.key,
      categoryKey: categoryKey ?? this.categoryKey,
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
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
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
    return (StringBuffer('SubcategoriesCompanion(')
          ..write('key: $key, ')
          ..write('categoryKey: $categoryKey, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameArMeta = const VerificationMeta('nameAr');
  @override
  late final GeneratedColumn<String> nameAr = GeneratedColumn<String>(
    'name_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories ("key")',
    ),
  );
  static const VerificationMeta _subcategoryKeyMeta = const VerificationMeta(
    'subcategoryKey',
  );
  @override
  late final GeneratedColumn<String> subcategoryKey = GeneratedColumn<String>(
    'subcategory_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subcategories ("key")',
    ),
  );
  static const VerificationMeta _defaultAmountPiastresMeta =
      const VerificationMeta('defaultAmountPiastres');
  @override
  late final GeneratedColumn<int> defaultAmountPiastres = GeneratedColumn<int>(
    'default_amount_piastres',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameAr,
    nameEn,
    categoryKey,
    subcategoryKey,
    defaultAmountPiastres,
    barcode,
    useCount,
    lastUsedAt,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_ar')) {
      context.handle(
        _nameArMeta,
        nameAr.isAcceptableOrUnknown(data['name_ar']!, _nameArMeta),
      );
    } else if (isInserting) {
      context.missing(_nameArMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('subcategory_key')) {
      context.handle(
        _subcategoryKeyMeta,
        subcategoryKey.isAcceptableOrUnknown(
          data['subcategory_key']!,
          _subcategoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('default_amount_piastres')) {
      context.handle(
        _defaultAmountPiastresMeta,
        defaultAmountPiastres.isAcceptableOrUnknown(
          data['default_amount_piastres']!,
          _defaultAmountPiastresMeta,
        ),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nameAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_ar'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      subcategoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_key'],
      ),
      defaultAmountPiastres: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_amount_piastres'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
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
  final String? subcategoryKey;
  final int? defaultAmountPiastres;
  final String? barcode;
  final int useCount;
  final DateTime? lastUsedAt;
  final bool archived;
  const Item({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.categoryKey,
    this.subcategoryKey,
    this.defaultAmountPiastres,
    this.barcode,
    required this.useCount,
    this.lastUsedAt,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_ar'] = Variable<String>(nameAr);
    map['name_en'] = Variable<String>(nameEn);
    map['category_key'] = Variable<String>(categoryKey);
    if (!nullToAbsent || subcategoryKey != null) {
      map['subcategory_key'] = Variable<String>(subcategoryKey);
    }
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
      subcategoryKey: subcategoryKey == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryKey),
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

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      nameAr: serializer.fromJson<String>(json['nameAr']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      subcategoryKey: serializer.fromJson<String?>(json['subcategoryKey']),
      defaultAmountPiastres: serializer.fromJson<int?>(
        json['defaultAmountPiastres'],
      ),
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
      'subcategoryKey': serializer.toJson<String?>(subcategoryKey),
      'defaultAmountPiastres': serializer.toJson<int?>(defaultAmountPiastres),
      'barcode': serializer.toJson<String?>(barcode),
      'useCount': serializer.toJson<int>(useCount),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Item copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? categoryKey,
    Value<String?> subcategoryKey = const Value.absent(),
    Value<int?> defaultAmountPiastres = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    int? useCount,
    Value<DateTime?> lastUsedAt = const Value.absent(),
    bool? archived,
  }) => Item(
    id: id ?? this.id,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    categoryKey: categoryKey ?? this.categoryKey,
    subcategoryKey: subcategoryKey.present
        ? subcategoryKey.value
        : this.subcategoryKey,
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
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      subcategoryKey: data.subcategoryKey.present
          ? data.subcategoryKey.value
          : this.subcategoryKey,
      defaultAmountPiastres: data.defaultAmountPiastres.present
          ? data.defaultAmountPiastres.value
          : this.defaultAmountPiastres,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
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
          ..write('subcategoryKey: $subcategoryKey, ')
          ..write('defaultAmountPiastres: $defaultAmountPiastres, ')
          ..write('barcode: $barcode, ')
          ..write('useCount: $useCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameAr,
    nameEn,
    categoryKey,
    subcategoryKey,
    defaultAmountPiastres,
    barcode,
    useCount,
    lastUsedAt,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.nameAr == this.nameAr &&
          other.nameEn == this.nameEn &&
          other.categoryKey == this.categoryKey &&
          other.subcategoryKey == this.subcategoryKey &&
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
  final Value<String?> subcategoryKey;
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
    this.subcategoryKey = const Value.absent(),
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
    this.subcategoryKey = const Value.absent(),
    this.defaultAmountPiastres = const Value.absent(),
    this.barcode = const Value.absent(),
    this.useCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nameAr = Value(nameAr),
       nameEn = Value(nameEn),
       categoryKey = Value(categoryKey);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? nameAr,
    Expression<String>? nameEn,
    Expression<String>? categoryKey,
    Expression<String>? subcategoryKey,
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
      if (subcategoryKey != null) 'subcategory_key': subcategoryKey,
      if (defaultAmountPiastres != null)
        'default_amount_piastres': defaultAmountPiastres,
      if (barcode != null) 'barcode': barcode,
      if (useCount != null) 'use_count': useCount,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? nameAr,
    Value<String>? nameEn,
    Value<String>? categoryKey,
    Value<String?>? subcategoryKey,
    Value<int?>? defaultAmountPiastres,
    Value<String?>? barcode,
    Value<int>? useCount,
    Value<DateTime?>? lastUsedAt,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      categoryKey: categoryKey ?? this.categoryKey,
      subcategoryKey: subcategoryKey ?? this.subcategoryKey,
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
    if (subcategoryKey.present) {
      map['subcategory_key'] = Variable<String>(subcategoryKey.value);
    }
    if (defaultAmountPiastres.present) {
      map['default_amount_piastres'] = Variable<int>(
        defaultAmountPiastres.value,
      );
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
          ..write('subcategoryKey: $subcategoryKey, ')
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

class $CaptureGroupsTable extends CaptureGroups
    with TableInfo<$CaptureGroupsTable, CaptureGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cleanTextMeta = const VerificationMeta(
    'cleanText',
  );
  @override
  late final GeneratedColumn<String> cleanText = GeneratedColumn<String>(
    'clean_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parsedByMeta = const VerificationMeta(
    'parsedBy',
  );
  @override
  late final GeneratedColumn<String> parsedBy = GeneratedColumn<String>(
    'parsed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    status,
    rawText,
    cleanText,
    parsedBy,
    date,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaptureGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    if (data.containsKey('clean_text')) {
      context.handle(
        _cleanTextMeta,
        cleanText.isAcceptableOrUnknown(data['clean_text']!, _cleanTextMeta),
      );
    }
    if (data.containsKey('parsed_by')) {
      context.handle(
        _parsedByMeta,
        parsedBy.isAcceptableOrUnknown(data['parsed_by']!, _parsedByMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
      cleanText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clean_text'],
      ),
      parsedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_by'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CaptureGroupsTable createAlias(String alias) {
    return $CaptureGroupsTable(attachedDatabase, alias);
  }
}

class CaptureGroup extends DataClass implements Insertable<CaptureGroup> {
  final String id;

  /// `voice`, `text`, `photo`, `barcode`, `import` or `manual`.
  final String kind;

  /// `draft` (not reviewed yet), `saved` (entries were written) or `note`
  /// (kept as a standalone note with no entries).
  final String status;

  /// The transcript or typed text exactly as captured, never altered.
  final String? rawText;

  /// The rewritten text from تحسين, kept beside [rawText].
  final String? cleanText;

  /// `local` or `gemini`.
  final String? parsedBy;
  final String date;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CaptureGroup({
    required this.id,
    required this.kind,
    required this.status,
    this.rawText,
    this.cleanText,
    this.parsedBy,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    if (!nullToAbsent || cleanText != null) {
      map['clean_text'] = Variable<String>(cleanText);
    }
    if (!nullToAbsent || parsedBy != null) {
      map['parsed_by'] = Variable<String>(parsedBy);
    }
    map['date'] = Variable<String>(date);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CaptureGroupsCompanion toCompanion(bool nullToAbsent) {
    return CaptureGroupsCompanion(
      id: Value(id),
      kind: Value(kind),
      status: Value(status),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      cleanText: cleanText == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanText),
      parsedBy: parsedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedBy),
      date: Value(date),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CaptureGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureGroup(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      cleanText: serializer.fromJson<String?>(json['cleanText']),
      parsedBy: serializer.fromJson<String?>(json['parsedBy']),
      date: serializer.fromJson<String>(json['date']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'rawText': serializer.toJson<String?>(rawText),
      'cleanText': serializer.toJson<String?>(cleanText),
      'parsedBy': serializer.toJson<String?>(parsedBy),
      'date': serializer.toJson<String>(date),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CaptureGroup copyWith({
    String? id,
    String? kind,
    String? status,
    Value<String?> rawText = const Value.absent(),
    Value<String?> cleanText = const Value.absent(),
    Value<String?> parsedBy = const Value.absent(),
    String? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CaptureGroup(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    rawText: rawText.present ? rawText.value : this.rawText,
    cleanText: cleanText.present ? cleanText.value : this.cleanText,
    parsedBy: parsedBy.present ? parsedBy.value : this.parsedBy,
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CaptureGroup copyWithCompanion(CaptureGroupsCompanion data) {
    return CaptureGroup(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      cleanText: data.cleanText.present ? data.cleanText.value : this.cleanText,
      parsedBy: data.parsedBy.present ? data.parsedBy.value : this.parsedBy,
      date: data.date.present ? data.date.value : this.date,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CaptureGroup(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('rawText: $rawText, ')
          ..write('cleanText: $cleanText, ')
          ..write('parsedBy: $parsedBy, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    status,
    rawText,
    cleanText,
    parsedBy,
    date,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureGroup &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.rawText == this.rawText &&
          other.cleanText == this.cleanText &&
          other.parsedBy == this.parsedBy &&
          other.date == this.date &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CaptureGroupsCompanion extends UpdateCompanion<CaptureGroup> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> status;
  final Value<String?> rawText;
  final Value<String?> cleanText;
  final Value<String?> parsedBy;
  final Value<String> date;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CaptureGroupsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.rawText = const Value.absent(),
    this.cleanText = const Value.absent(),
    this.parsedBy = const Value.absent(),
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureGroupsCompanion.insert({
    required String id,
    required String kind,
    required String status,
    this.rawText = const Value.absent(),
    this.cleanText = const Value.absent(),
    this.parsedBy = const Value.absent(),
    required String date,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       status = Value(status),
       date = Value(date),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CaptureGroup> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? rawText,
    Expression<String>? cleanText,
    Expression<String>? parsedBy,
    Expression<String>? date,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (rawText != null) 'raw_text': rawText,
      if (cleanText != null) 'clean_text': cleanText,
      if (parsedBy != null) 'parsed_by': parsedBy,
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? status,
    Value<String?>? rawText,
    Value<String?>? cleanText,
    Value<String?>? parsedBy,
    Value<String>? date,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CaptureGroupsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      rawText: rawText ?? this.rawText,
      cleanText: cleanText ?? this.cleanText,
      parsedBy: parsedBy ?? this.parsedBy,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (cleanText.present) {
      map['clean_text'] = Variable<String>(cleanText.value);
    }
    if (parsedBy.present) {
      map['parsed_by'] = Variable<String>(parsedBy.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureGroupsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('rawText: $rawText, ')
          ..write('cleanText: $cleanText, ')
          ..write('parsedBy: $parsedBy, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPiastresMeta = const VerificationMeta(
    'amountPiastres',
  );
  @override
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
    'amount_piastres',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories ("key")',
    ),
  );
  static const VerificationMeta _subcategoryKeyMeta = const VerificationMeta(
    'subcategoryKey',
  );
  @override
  late final GeneratedColumn<String> subcategoryKey = GeneratedColumn<String>(
    'subcategory_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subcategories ("key")',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Cash'),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMilliMeta = const VerificationMeta(
    'quantityMilli',
  );
  @override
  late final GeneratedColumn<int> quantityMilli = GeneratedColumn<int>(
    'quantity_milli',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPricePiastresMeta = const VerificationMeta(
    'unitPricePiastres',
  );
  @override
  late final GeneratedColumn<int> unitPricePiastres = GeneratedColumn<int>(
    'unit_price_piastres',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captureGroupIdMeta = const VerificationMeta(
    'captureGroupId',
  );
  @override
  late final GeneratedColumn<String> captureGroupId = GeneratedColumn<String>(
    'capture_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES capture_groups (id)',
    ),
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    amountPiastres,
    categoryKey,
    subcategoryKey,
    itemId,
    description,
    paymentMethod,
    photoPath,
    source,
    note,
    createdAt,
    updatedAt,
    deletedAt,
    quantityMilli,
    unit,
    unitPricePiastres,
    captureGroupId,
    externalId,
    reference,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_piastres')) {
      context.handle(
        _amountPiastresMeta,
        amountPiastres.isAcceptableOrUnknown(
          data['amount_piastres']!,
          _amountPiastresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPiastresMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('subcategory_key')) {
      context.handle(
        _subcategoryKeyMeta,
        subcategoryKey.isAcceptableOrUnknown(
          data['subcategory_key']!,
          _subcategoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('quantity_milli')) {
      context.handle(
        _quantityMilliMeta,
        quantityMilli.isAcceptableOrUnknown(
          data['quantity_milli']!,
          _quantityMilliMeta,
        ),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('unit_price_piastres')) {
      context.handle(
        _unitPricePiastresMeta,
        unitPricePiastres.isAcceptableOrUnknown(
          data['unit_price_piastres']!,
          _unitPricePiastresMeta,
        ),
      );
    }
    if (data.containsKey('capture_group_id')) {
      context.handle(
        _captureGroupIdMeta,
        captureGroupId.isAcceptableOrUnknown(
          data['capture_group_id']!,
          _captureGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      amountPiastres: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_piastres'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      subcategoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_key'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      quantityMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_milli'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      unitPricePiastres: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_piastres'],
      ),
      captureGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_group_id'],
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
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
  final String? subcategoryKey;
  final String? itemId;
  final String description;
  final String paymentMethod;

  /// Kept for rows written before v3 only. v3 stores photos as
  /// [Attachments] rows (the migration backfills one per photoPath) and
  /// never writes this column again.
  final String? photoPath;
  final String source;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Quantity in milli-units: 1000 is one unit, 1500 is 1.5 كيلو. Null
  /// means one.
  final int? quantityMilli;

  /// English unit key (`piece`, `kg`, `g`, `liter`, ...); see `EntryUnit`.
  final String? unit;
  final int? unitPricePiastres;
  final String? captureGroupId;

  /// Import identity (an import pack's `ref`), unique when set.
  final String? externalId;

  /// Payment reference, e.g. an InstaPay transaction number.
  final String? reference;
  const Entry({
    required this.id,
    required this.date,
    required this.amountPiastres,
    required this.categoryKey,
    this.subcategoryKey,
    this.itemId,
    required this.description,
    required this.paymentMethod,
    this.photoPath,
    required this.source,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.quantityMilli,
    this.unit,
    this.unitPricePiastres,
    this.captureGroupId,
    this.externalId,
    this.reference,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['amount_piastres'] = Variable<int>(amountPiastres);
    map['category_key'] = Variable<String>(categoryKey);
    if (!nullToAbsent || subcategoryKey != null) {
      map['subcategory_key'] = Variable<String>(subcategoryKey);
    }
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
    if (!nullToAbsent || quantityMilli != null) {
      map['quantity_milli'] = Variable<int>(quantityMilli);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || unitPricePiastres != null) {
      map['unit_price_piastres'] = Variable<int>(unitPricePiastres);
    }
    if (!nullToAbsent || captureGroupId != null) {
      map['capture_group_id'] = Variable<String>(captureGroupId);
    }
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      date: Value(date),
      amountPiastres: Value(amountPiastres),
      categoryKey: Value(categoryKey),
      subcategoryKey: subcategoryKey == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryKey),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
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
      quantityMilli: quantityMilli == null && nullToAbsent
          ? const Value.absent()
          : Value(quantityMilli),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      unitPricePiastres: unitPricePiastres == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPricePiastres),
      captureGroupId: captureGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(captureGroupId),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      amountPiastres: serializer.fromJson<int>(json['amountPiastres']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      subcategoryKey: serializer.fromJson<String?>(json['subcategoryKey']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      description: serializer.fromJson<String>(json['description']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      source: serializer.fromJson<String>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      quantityMilli: serializer.fromJson<int?>(json['quantityMilli']),
      unit: serializer.fromJson<String?>(json['unit']),
      unitPricePiastres: serializer.fromJson<int?>(json['unitPricePiastres']),
      captureGroupId: serializer.fromJson<String?>(json['captureGroupId']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      reference: serializer.fromJson<String?>(json['reference']),
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
      'subcategoryKey': serializer.toJson<String?>(subcategoryKey),
      'itemId': serializer.toJson<String?>(itemId),
      'description': serializer.toJson<String>(description),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'photoPath': serializer.toJson<String?>(photoPath),
      'source': serializer.toJson<String>(source),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'quantityMilli': serializer.toJson<int?>(quantityMilli),
      'unit': serializer.toJson<String?>(unit),
      'unitPricePiastres': serializer.toJson<int?>(unitPricePiastres),
      'captureGroupId': serializer.toJson<String?>(captureGroupId),
      'externalId': serializer.toJson<String?>(externalId),
      'reference': serializer.toJson<String?>(reference),
    };
  }

  Entry copyWith({
    String? id,
    String? date,
    int? amountPiastres,
    String? categoryKey,
    Value<String?> subcategoryKey = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    String? description,
    String? paymentMethod,
    Value<String?> photoPath = const Value.absent(),
    String? source,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<int?> quantityMilli = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<int?> unitPricePiastres = const Value.absent(),
    Value<String?> captureGroupId = const Value.absent(),
    Value<String?> externalId = const Value.absent(),
    Value<String?> reference = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    date: date ?? this.date,
    amountPiastres: amountPiastres ?? this.amountPiastres,
    categoryKey: categoryKey ?? this.categoryKey,
    subcategoryKey: subcategoryKey.present
        ? subcategoryKey.value
        : this.subcategoryKey,
    itemId: itemId.present ? itemId.value : this.itemId,
    description: description ?? this.description,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    source: source ?? this.source,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    quantityMilli: quantityMilli.present
        ? quantityMilli.value
        : this.quantityMilli,
    unit: unit.present ? unit.value : this.unit,
    unitPricePiastres: unitPricePiastres.present
        ? unitPricePiastres.value
        : this.unitPricePiastres,
    captureGroupId: captureGroupId.present
        ? captureGroupId.value
        : this.captureGroupId,
    externalId: externalId.present ? externalId.value : this.externalId,
    reference: reference.present ? reference.value : this.reference,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      amountPiastres: data.amountPiastres.present
          ? data.amountPiastres.value
          : this.amountPiastres,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      subcategoryKey: data.subcategoryKey.present
          ? data.subcategoryKey.value
          : this.subcategoryKey,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      description: data.description.present
          ? data.description.value
          : this.description,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      quantityMilli: data.quantityMilli.present
          ? data.quantityMilli.value
          : this.quantityMilli,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitPricePiastres: data.unitPricePiastres.present
          ? data.unitPricePiastres.value
          : this.unitPricePiastres,
      captureGroupId: data.captureGroupId.present
          ? data.captureGroupId.value
          : this.captureGroupId,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      reference: data.reference.present ? data.reference.value : this.reference,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('subcategoryKey: $subcategoryKey, ')
          ..write('itemId: $itemId, ')
          ..write('description: $description, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('photoPath: $photoPath, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('quantityMilli: $quantityMilli, ')
          ..write('unit: $unit, ')
          ..write('unitPricePiastres: $unitPricePiastres, ')
          ..write('captureGroupId: $captureGroupId, ')
          ..write('externalId: $externalId, ')
          ..write('reference: $reference')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    amountPiastres,
    categoryKey,
    subcategoryKey,
    itemId,
    description,
    paymentMethod,
    photoPath,
    source,
    note,
    createdAt,
    updatedAt,
    deletedAt,
    quantityMilli,
    unit,
    unitPricePiastres,
    captureGroupId,
    externalId,
    reference,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.date == this.date &&
          other.amountPiastres == this.amountPiastres &&
          other.categoryKey == this.categoryKey &&
          other.subcategoryKey == this.subcategoryKey &&
          other.itemId == this.itemId &&
          other.description == this.description &&
          other.paymentMethod == this.paymentMethod &&
          other.photoPath == this.photoPath &&
          other.source == this.source &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.quantityMilli == this.quantityMilli &&
          other.unit == this.unit &&
          other.unitPricePiastres == this.unitPricePiastres &&
          other.captureGroupId == this.captureGroupId &&
          other.externalId == this.externalId &&
          other.reference == this.reference);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> date;
  final Value<int> amountPiastres;
  final Value<String> categoryKey;
  final Value<String?> subcategoryKey;
  final Value<String?> itemId;
  final Value<String> description;
  final Value<String> paymentMethod;
  final Value<String?> photoPath;
  final Value<String> source;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int?> quantityMilli;
  final Value<String?> unit;
  final Value<int?> unitPricePiastres;
  final Value<String?> captureGroupId;
  final Value<String?> externalId;
  final Value<String?> reference;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.amountPiastres = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.subcategoryKey = const Value.absent(),
    this.itemId = const Value.absent(),
    this.description = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.quantityMilli = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPricePiastres = const Value.absent(),
    this.captureGroupId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.reference = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String date,
    required int amountPiastres,
    required String categoryKey,
    this.subcategoryKey = const Value.absent(),
    this.itemId = const Value.absent(),
    this.description = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.quantityMilli = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPricePiastres = const Value.absent(),
    this.captureGroupId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.reference = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
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
    Expression<String>? subcategoryKey,
    Expression<String>? itemId,
    Expression<String>? description,
    Expression<String>? paymentMethod,
    Expression<String>? photoPath,
    Expression<String>? source,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? quantityMilli,
    Expression<String>? unit,
    Expression<int>? unitPricePiastres,
    Expression<String>? captureGroupId,
    Expression<String>? externalId,
    Expression<String>? reference,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (amountPiastres != null) 'amount_piastres': amountPiastres,
      if (categoryKey != null) 'category_key': categoryKey,
      if (subcategoryKey != null) 'subcategory_key': subcategoryKey,
      if (itemId != null) 'item_id': itemId,
      if (description != null) 'description': description,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (photoPath != null) 'photo_path': photoPath,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (quantityMilli != null) 'quantity_milli': quantityMilli,
      if (unit != null) 'unit': unit,
      if (unitPricePiastres != null) 'unit_price_piastres': unitPricePiastres,
      if (captureGroupId != null) 'capture_group_id': captureGroupId,
      if (externalId != null) 'external_id': externalId,
      if (reference != null) 'reference': reference,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<int>? amountPiastres,
    Value<String>? categoryKey,
    Value<String?>? subcategoryKey,
    Value<String?>? itemId,
    Value<String>? description,
    Value<String>? paymentMethod,
    Value<String?>? photoPath,
    Value<String>? source,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int?>? quantityMilli,
    Value<String?>? unit,
    Value<int?>? unitPricePiastres,
    Value<String?>? captureGroupId,
    Value<String?>? externalId,
    Value<String?>? reference,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      amountPiastres: amountPiastres ?? this.amountPiastres,
      categoryKey: categoryKey ?? this.categoryKey,
      subcategoryKey: subcategoryKey ?? this.subcategoryKey,
      itemId: itemId ?? this.itemId,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      photoPath: photoPath ?? this.photoPath,
      source: source ?? this.source,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      quantityMilli: quantityMilli ?? this.quantityMilli,
      unit: unit ?? this.unit,
      unitPricePiastres: unitPricePiastres ?? this.unitPricePiastres,
      captureGroupId: captureGroupId ?? this.captureGroupId,
      externalId: externalId ?? this.externalId,
      reference: reference ?? this.reference,
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
    if (subcategoryKey.present) {
      map['subcategory_key'] = Variable<String>(subcategoryKey.value);
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
    if (quantityMilli.present) {
      map['quantity_milli'] = Variable<int>(quantityMilli.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitPricePiastres.present) {
      map['unit_price_piastres'] = Variable<int>(unitPricePiastres.value);
    }
    if (captureGroupId.present) {
      map['capture_group_id'] = Variable<String>(captureGroupId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
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
          ..write('subcategoryKey: $subcategoryKey, ')
          ..write('itemId: $itemId, ')
          ..write('description: $description, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('photoPath: $photoPath, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('quantityMilli: $quantityMilli, ')
          ..write('unit: $unit, ')
          ..write('unitPricePiastres: $unitPricePiastres, ')
          ..write('captureGroupId: $captureGroupId, ')
          ..write('externalId: $externalId, ')
          ..write('reference: $reference, ')
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
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datePaidMeta = const VerificationMeta(
    'datePaid',
  );
  @override
  late final GeneratedColumn<String> datePaid = GeneratedColumn<String>(
    'date_paid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPiastresMeta = const VerificationMeta(
    'amountPiastres',
  );
  @override
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
    'amount_piastres',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidencePhotoPathMeta = const VerificationMeta(
    'evidencePhotoPath',
  );
  @override
  late final GeneratedColumn<String> evidencePhotoPath =
      GeneratedColumn<String>(
        'evidence_photo_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datePaid,
    amountPiastres,
    evidencePhotoPath,
    note,
    externalId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'salary_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<SalaryPeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date_paid')) {
      context.handle(
        _datePaidMeta,
        datePaid.isAcceptableOrUnknown(data['date_paid']!, _datePaidMeta),
      );
    } else if (isInserting) {
      context.missing(_datePaidMeta);
    }
    if (data.containsKey('amount_piastres')) {
      context.handle(
        _amountPiastresMeta,
        amountPiastres.isAcceptableOrUnknown(
          data['amount_piastres']!,
          _amountPiastresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPiastresMeta);
    }
    if (data.containsKey('evidence_photo_path')) {
      context.handle(
        _evidencePhotoPathMeta,
        evidencePhotoPath.isAcceptableOrUnknown(
          data['evidence_photo_path']!,
          _evidencePhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalaryPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalaryPeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      datePaid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_paid'],
      )!,
      amountPiastres: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_piastres'],
      )!,
      evidencePhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_photo_path'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
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

  /// Import identity, unique when set (v3).
  final String? externalId;
  const SalaryPeriod({
    required this.id,
    required this.datePaid,
    required this.amountPiastres,
    this.evidencePhotoPath,
    this.note,
    this.externalId,
  });
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
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
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
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
    );
  }

  factory SalaryPeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalaryPeriod(
      id: serializer.fromJson<String>(json['id']),
      datePaid: serializer.fromJson<String>(json['datePaid']),
      amountPiastres: serializer.fromJson<int>(json['amountPiastres']),
      evidencePhotoPath: serializer.fromJson<String?>(
        json['evidencePhotoPath'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      externalId: serializer.fromJson<String?>(json['externalId']),
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
      'externalId': serializer.toJson<String?>(externalId),
    };
  }

  SalaryPeriod copyWith({
    String? id,
    String? datePaid,
    int? amountPiastres,
    Value<String?> evidencePhotoPath = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> externalId = const Value.absent(),
  }) => SalaryPeriod(
    id: id ?? this.id,
    datePaid: datePaid ?? this.datePaid,
    amountPiastres: amountPiastres ?? this.amountPiastres,
    evidencePhotoPath: evidencePhotoPath.present
        ? evidencePhotoPath.value
        : this.evidencePhotoPath,
    note: note.present ? note.value : this.note,
    externalId: externalId.present ? externalId.value : this.externalId,
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
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalaryPeriod(')
          ..write('id: $id, ')
          ..write('datePaid: $datePaid, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('evidencePhotoPath: $evidencePhotoPath, ')
          ..write('note: $note, ')
          ..write('externalId: $externalId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    datePaid,
    amountPiastres,
    evidencePhotoPath,
    note,
    externalId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalaryPeriod &&
          other.id == this.id &&
          other.datePaid == this.datePaid &&
          other.amountPiastres == this.amountPiastres &&
          other.evidencePhotoPath == this.evidencePhotoPath &&
          other.note == this.note &&
          other.externalId == this.externalId);
}

class SalaryPeriodsCompanion extends UpdateCompanion<SalaryPeriod> {
  final Value<String> id;
  final Value<String> datePaid;
  final Value<int> amountPiastres;
  final Value<String?> evidencePhotoPath;
  final Value<String?> note;
  final Value<String?> externalId;
  final Value<int> rowid;
  const SalaryPeriodsCompanion({
    this.id = const Value.absent(),
    this.datePaid = const Value.absent(),
    this.amountPiastres = const Value.absent(),
    this.evidencePhotoPath = const Value.absent(),
    this.note = const Value.absent(),
    this.externalId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalaryPeriodsCompanion.insert({
    required String id,
    required String datePaid,
    required int amountPiastres,
    this.evidencePhotoPath = const Value.absent(),
    this.note = const Value.absent(),
    this.externalId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       datePaid = Value(datePaid),
       amountPiastres = Value(amountPiastres);
  static Insertable<SalaryPeriod> custom({
    Expression<String>? id,
    Expression<String>? datePaid,
    Expression<int>? amountPiastres,
    Expression<String>? evidencePhotoPath,
    Expression<String>? note,
    Expression<String>? externalId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datePaid != null) 'date_paid': datePaid,
      if (amountPiastres != null) 'amount_piastres': amountPiastres,
      if (evidencePhotoPath != null) 'evidence_photo_path': evidencePhotoPath,
      if (note != null) 'note': note,
      if (externalId != null) 'external_id': externalId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalaryPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? datePaid,
    Value<int>? amountPiastres,
    Value<String?>? evidencePhotoPath,
    Value<String?>? note,
    Value<String?>? externalId,
    Value<int>? rowid,
  }) {
    return SalaryPeriodsCompanion(
      id: id ?? this.id,
      datePaid: datePaid ?? this.datePaid,
      amountPiastres: amountPiastres ?? this.amountPiastres,
      evidencePhotoPath: evidencePhotoPath ?? this.evidencePhotoPath,
      note: note ?? this.note,
      externalId: externalId ?? this.externalId,
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
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
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
          ..write('externalId: $externalId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _captureGroupIdMeta = const VerificationMeta(
    'captureGroupId',
  );
  @override
  late final GeneratedColumn<String> captureGroupId = GeneratedColumn<String>(
    'capture_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES capture_groups (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    captureGroupId,
    kind,
    path,
    body,
    transcript,
    durationMs,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('capture_group_id')) {
      context.handle(
        _captureGroupIdMeta,
        captureGroupId.isAcceptableOrUnknown(
          data['capture_group_id']!,
          _captureGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      captureGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_group_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String? entryId;
  final String? captureGroupId;

  /// `photo`, `voice`, `text` or `file`.
  final String kind;

  /// Relative to the app documents directory, never absolute: Android can
  /// move that directory on restore. New files go under
  /// `attachments/<yyyy-MM>/<id>.<ext>`; backfilled photos keep their
  /// `photos/...` path.
  final String? path;

  /// Body of a text note. Spec §5 calls this column `text`; it is `body`
  /// because drift's generated migration-test schema names each column
  /// getter after its SQL name, and a getter called `text` collides with
  /// drift's own `Table.text()` builder.
  final String? body;
  final String? transcript;
  final int? durationMs;
  final DateTime createdAt;
  const Attachment({
    required this.id,
    this.entryId,
    this.captureGroupId,
    required this.kind,
    this.path,
    this.body,
    this.transcript,
    this.durationMs,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    if (!nullToAbsent || captureGroupId != null) {
      map['capture_group_id'] = Variable<String>(captureGroupId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      captureGroupId: captureGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(captureGroupId),
      kind: Value(kind),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      captureGroupId: serializer.fromJson<String?>(json['captureGroupId']),
      kind: serializer.fromJson<String>(json['kind']),
      path: serializer.fromJson<String?>(json['path']),
      body: serializer.fromJson<String?>(json['body']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryId': serializer.toJson<String?>(entryId),
      'captureGroupId': serializer.toJson<String?>(captureGroupId),
      'kind': serializer.toJson<String>(kind),
      'path': serializer.toJson<String?>(path),
      'body': serializer.toJson<String?>(body),
      'transcript': serializer.toJson<String?>(transcript),
      'durationMs': serializer.toJson<int?>(durationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Attachment copyWith({
    String? id,
    Value<String?> entryId = const Value.absent(),
    Value<String?> captureGroupId = const Value.absent(),
    String? kind,
    Value<String?> path = const Value.absent(),
    Value<String?> body = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    DateTime? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    entryId: entryId.present ? entryId.value : this.entryId,
    captureGroupId: captureGroupId.present
        ? captureGroupId.value
        : this.captureGroupId,
    kind: kind ?? this.kind,
    path: path.present ? path.value : this.path,
    body: body.present ? body.value : this.body,
    transcript: transcript.present ? transcript.value : this.transcript,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      captureGroupId: data.captureGroupId.present
          ? data.captureGroupId.value
          : this.captureGroupId,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      body: data.body.present ? data.body.value : this.body,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('captureGroupId: $captureGroupId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('body: $body, ')
          ..write('transcript: $transcript, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    captureGroupId,
    kind,
    path,
    body,
    transcript,
    durationMs,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.captureGroupId == this.captureGroupId &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.body == this.body &&
          other.transcript == this.transcript &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String?> entryId;
  final Value<String?> captureGroupId;
  final Value<String> kind;
  final Value<String?> path;
  final Value<String?> body;
  final Value<String?> transcript;
  final Value<int?> durationMs;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.captureGroupId = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.body = const Value.absent(),
    this.transcript = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    this.entryId = const Value.absent(),
    this.captureGroupId = const Value.absent(),
    required String kind,
    this.path = const Value.absent(),
    this.body = const Value.absent(),
    this.transcript = const Value.absent(),
    this.durationMs = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? entryId,
    Expression<String>? captureGroupId,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<String>? body,
    Expression<String>? transcript,
    Expression<int>? durationMs,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (captureGroupId != null) 'capture_group_id': captureGroupId,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (body != null) 'body': body,
      if (transcript != null) 'transcript': transcript,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? entryId,
    Value<String?>? captureGroupId,
    Value<String>? kind,
    Value<String?>? path,
    Value<String?>? body,
    Value<String?>? transcript,
    Value<int?>? durationMs,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      captureGroupId: captureGroupId ?? this.captureGroupId,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      body: body ?? this.body,
      transcript: transcript ?? this.transcript,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (captureGroupId.present) {
      map['capture_group_id'] = Variable<String>(captureGroupId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('captureGroupId: $captureGroupId, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('body: $body, ')
          ..write('transcript: $transcript, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemAliasesTable extends ItemAliases
    with TableInfo<$ItemAliasesTable, ItemAlias> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [alias, itemId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemAlias> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {alias};
  @override
  ItemAlias map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemAlias(
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ItemAliasesTable createAlias(String alias) {
    return $ItemAliasesTable(attachedDatabase, alias);
  }
}

class ItemAlias extends DataClass implements Insertable<ItemAlias> {
  final String alias;
  final String itemId;
  final DateTime createdAt;
  const ItemAlias({
    required this.alias,
    required this.itemId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alias'] = Variable<String>(alias);
    map['item_id'] = Variable<String>(itemId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ItemAliasesCompanion toCompanion(bool nullToAbsent) {
    return ItemAliasesCompanion(
      alias: Value(alias),
      itemId: Value(itemId),
      createdAt: Value(createdAt),
    );
  }

  factory ItemAlias.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemAlias(
      alias: serializer.fromJson<String>(json['alias']),
      itemId: serializer.fromJson<String>(json['itemId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alias': serializer.toJson<String>(alias),
      'itemId': serializer.toJson<String>(itemId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ItemAlias copyWith({String? alias, String? itemId, DateTime? createdAt}) =>
      ItemAlias(
        alias: alias ?? this.alias,
        itemId: itemId ?? this.itemId,
        createdAt: createdAt ?? this.createdAt,
      );
  ItemAlias copyWithCompanion(ItemAliasesCompanion data) {
    return ItemAlias(
      alias: data.alias.present ? data.alias.value : this.alias,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemAlias(')
          ..write('alias: $alias, ')
          ..write('itemId: $itemId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(alias, itemId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemAlias &&
          other.alias == this.alias &&
          other.itemId == this.itemId &&
          other.createdAt == this.createdAt);
}

class ItemAliasesCompanion extends UpdateCompanion<ItemAlias> {
  final Value<String> alias;
  final Value<String> itemId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ItemAliasesCompanion({
    this.alias = const Value.absent(),
    this.itemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemAliasesCompanion.insert({
    required String alias,
    required String itemId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : alias = Value(alias),
       itemId = Value(itemId),
       createdAt = Value(createdAt);
  static Insertable<ItemAlias> custom({
    Expression<String>? alias,
    Expression<String>? itemId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (alias != null) 'alias': alias,
      if (itemId != null) 'item_id': itemId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemAliasesCompanion copyWith({
    Value<String>? alias,
    Value<String>? itemId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ItemAliasesCompanion(
      alias: alias ?? this.alias,
      itemId: itemId ?? this.itemId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemAliasesCompanion(')
          ..write('alias: $alias, ')
          ..write('itemId: $itemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringBillsTable extends RecurringBills
    with TableInfo<$RecurringBillsTable, RecurringBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringBillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameArMeta = const VerificationMeta('nameAr');
  @override
  late final GeneratedColumn<String> nameAr = GeneratedColumn<String>(
    'name_ar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPiastresMeta = const VerificationMeta(
    'amountPiastres',
  );
  @override
  late final GeneratedColumn<int> amountPiastres = GeneratedColumn<int>(
    'amount_piastres',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories ("key")',
    ),
  );
  static const VerificationMeta _subcategoryKeyMeta = const VerificationMeta(
    'subcategoryKey',
  );
  @override
  late final GeneratedColumn<String> subcategoryKey = GeneratedColumn<String>(
    'subcategory_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subcategories ("key")',
    ),
  );
  static const VerificationMeta _everyMonthsMeta = const VerificationMeta(
    'everyMonths',
  );
  @override
  late final GeneratedColumn<int> everyMonths = GeneratedColumn<int>(
    'every_months',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nextDueMeta = const VerificationMeta(
    'nextDue',
  );
  @override
  late final GeneratedColumn<String> nextDue = GeneratedColumn<String>(
    'next_due',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindDaysBeforeMeta = const VerificationMeta(
    'remindDaysBefore',
  );
  @override
  late final GeneratedColumn<int> remindDaysBefore = GeneratedColumn<int>(
    'remind_days_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nameAr,
    amountPiastres,
    categoryKey,
    subcategoryKey,
    everyMonths,
    nextDue,
    remindDaysBefore,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_ar')) {
      context.handle(
        _nameArMeta,
        nameAr.isAcceptableOrUnknown(data['name_ar']!, _nameArMeta),
      );
    } else if (isInserting) {
      context.missing(_nameArMeta);
    }
    if (data.containsKey('amount_piastres')) {
      context.handle(
        _amountPiastresMeta,
        amountPiastres.isAcceptableOrUnknown(
          data['amount_piastres']!,
          _amountPiastresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPiastresMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('subcategory_key')) {
      context.handle(
        _subcategoryKeyMeta,
        subcategoryKey.isAcceptableOrUnknown(
          data['subcategory_key']!,
          _subcategoryKeyMeta,
        ),
      );
    }
    if (data.containsKey('every_months')) {
      context.handle(
        _everyMonthsMeta,
        everyMonths.isAcceptableOrUnknown(
          data['every_months']!,
          _everyMonthsMeta,
        ),
      );
    }
    if (data.containsKey('next_due')) {
      context.handle(
        _nextDueMeta,
        nextDue.isAcceptableOrUnknown(data['next_due']!, _nextDueMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueMeta);
    }
    if (data.containsKey('remind_days_before')) {
      context.handle(
        _remindDaysBeforeMeta,
        remindDaysBefore.isAcceptableOrUnknown(
          data['remind_days_before']!,
          _remindDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringBill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nameAr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_ar'],
      )!,
      amountPiastres: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_piastres'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      subcategoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_key'],
      ),
      everyMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}every_months'],
      )!,
      nextDue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_due'],
      )!,
      remindDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_days_before'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $RecurringBillsTable createAlias(String alias) {
    return $RecurringBillsTable(attachedDatabase, alias);
  }
}

class RecurringBill extends DataClass implements Insertable<RecurringBill> {
  final String id;
  final String nameAr;
  final int amountPiastres;
  final String categoryKey;
  final String? subcategoryKey;
  final int everyMonths;
  final String nextDue;
  final int remindDaysBefore;
  final bool archived;
  const RecurringBill({
    required this.id,
    required this.nameAr,
    required this.amountPiastres,
    required this.categoryKey,
    this.subcategoryKey,
    required this.everyMonths,
    required this.nextDue,
    required this.remindDaysBefore,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_ar'] = Variable<String>(nameAr);
    map['amount_piastres'] = Variable<int>(amountPiastres);
    map['category_key'] = Variable<String>(categoryKey);
    if (!nullToAbsent || subcategoryKey != null) {
      map['subcategory_key'] = Variable<String>(subcategoryKey);
    }
    map['every_months'] = Variable<int>(everyMonths);
    map['next_due'] = Variable<String>(nextDue);
    map['remind_days_before'] = Variable<int>(remindDaysBefore);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  RecurringBillsCompanion toCompanion(bool nullToAbsent) {
    return RecurringBillsCompanion(
      id: Value(id),
      nameAr: Value(nameAr),
      amountPiastres: Value(amountPiastres),
      categoryKey: Value(categoryKey),
      subcategoryKey: subcategoryKey == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryKey),
      everyMonths: Value(everyMonths),
      nextDue: Value(nextDue),
      remindDaysBefore: Value(remindDaysBefore),
      archived: Value(archived),
    );
  }

  factory RecurringBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringBill(
      id: serializer.fromJson<String>(json['id']),
      nameAr: serializer.fromJson<String>(json['nameAr']),
      amountPiastres: serializer.fromJson<int>(json['amountPiastres']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      subcategoryKey: serializer.fromJson<String?>(json['subcategoryKey']),
      everyMonths: serializer.fromJson<int>(json['everyMonths']),
      nextDue: serializer.fromJson<String>(json['nextDue']),
      remindDaysBefore: serializer.fromJson<int>(json['remindDaysBefore']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nameAr': serializer.toJson<String>(nameAr),
      'amountPiastres': serializer.toJson<int>(amountPiastres),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'subcategoryKey': serializer.toJson<String?>(subcategoryKey),
      'everyMonths': serializer.toJson<int>(everyMonths),
      'nextDue': serializer.toJson<String>(nextDue),
      'remindDaysBefore': serializer.toJson<int>(remindDaysBefore),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  RecurringBill copyWith({
    String? id,
    String? nameAr,
    int? amountPiastres,
    String? categoryKey,
    Value<String?> subcategoryKey = const Value.absent(),
    int? everyMonths,
    String? nextDue,
    int? remindDaysBefore,
    bool? archived,
  }) => RecurringBill(
    id: id ?? this.id,
    nameAr: nameAr ?? this.nameAr,
    amountPiastres: amountPiastres ?? this.amountPiastres,
    categoryKey: categoryKey ?? this.categoryKey,
    subcategoryKey: subcategoryKey.present
        ? subcategoryKey.value
        : this.subcategoryKey,
    everyMonths: everyMonths ?? this.everyMonths,
    nextDue: nextDue ?? this.nextDue,
    remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
    archived: archived ?? this.archived,
  );
  RecurringBill copyWithCompanion(RecurringBillsCompanion data) {
    return RecurringBill(
      id: data.id.present ? data.id.value : this.id,
      nameAr: data.nameAr.present ? data.nameAr.value : this.nameAr,
      amountPiastres: data.amountPiastres.present
          ? data.amountPiastres.value
          : this.amountPiastres,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      subcategoryKey: data.subcategoryKey.present
          ? data.subcategoryKey.value
          : this.subcategoryKey,
      everyMonths: data.everyMonths.present
          ? data.everyMonths.value
          : this.everyMonths,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      remindDaysBefore: data.remindDaysBefore.present
          ? data.remindDaysBefore.value
          : this.remindDaysBefore,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringBill(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('subcategoryKey: $subcategoryKey, ')
          ..write('everyMonths: $everyMonths, ')
          ..write('nextDue: $nextDue, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nameAr,
    amountPiastres,
    categoryKey,
    subcategoryKey,
    everyMonths,
    nextDue,
    remindDaysBefore,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringBill &&
          other.id == this.id &&
          other.nameAr == this.nameAr &&
          other.amountPiastres == this.amountPiastres &&
          other.categoryKey == this.categoryKey &&
          other.subcategoryKey == this.subcategoryKey &&
          other.everyMonths == this.everyMonths &&
          other.nextDue == this.nextDue &&
          other.remindDaysBefore == this.remindDaysBefore &&
          other.archived == this.archived);
}

class RecurringBillsCompanion extends UpdateCompanion<RecurringBill> {
  final Value<String> id;
  final Value<String> nameAr;
  final Value<int> amountPiastres;
  final Value<String> categoryKey;
  final Value<String?> subcategoryKey;
  final Value<int> everyMonths;
  final Value<String> nextDue;
  final Value<int> remindDaysBefore;
  final Value<bool> archived;
  final Value<int> rowid;
  const RecurringBillsCompanion({
    this.id = const Value.absent(),
    this.nameAr = const Value.absent(),
    this.amountPiastres = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.subcategoryKey = const Value.absent(),
    this.everyMonths = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.remindDaysBefore = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringBillsCompanion.insert({
    required String id,
    required String nameAr,
    required int amountPiastres,
    required String categoryKey,
    this.subcategoryKey = const Value.absent(),
    this.everyMonths = const Value.absent(),
    required String nextDue,
    this.remindDaysBefore = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nameAr = Value(nameAr),
       amountPiastres = Value(amountPiastres),
       categoryKey = Value(categoryKey),
       nextDue = Value(nextDue);
  static Insertable<RecurringBill> custom({
    Expression<String>? id,
    Expression<String>? nameAr,
    Expression<int>? amountPiastres,
    Expression<String>? categoryKey,
    Expression<String>? subcategoryKey,
    Expression<int>? everyMonths,
    Expression<String>? nextDue,
    Expression<int>? remindDaysBefore,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameAr != null) 'name_ar': nameAr,
      if (amountPiastres != null) 'amount_piastres': amountPiastres,
      if (categoryKey != null) 'category_key': categoryKey,
      if (subcategoryKey != null) 'subcategory_key': subcategoryKey,
      if (everyMonths != null) 'every_months': everyMonths,
      if (nextDue != null) 'next_due': nextDue,
      if (remindDaysBefore != null) 'remind_days_before': remindDaysBefore,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringBillsCompanion copyWith({
    Value<String>? id,
    Value<String>? nameAr,
    Value<int>? amountPiastres,
    Value<String>? categoryKey,
    Value<String?>? subcategoryKey,
    Value<int>? everyMonths,
    Value<String>? nextDue,
    Value<int>? remindDaysBefore,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return RecurringBillsCompanion(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      amountPiastres: amountPiastres ?? this.amountPiastres,
      categoryKey: categoryKey ?? this.categoryKey,
      subcategoryKey: subcategoryKey ?? this.subcategoryKey,
      everyMonths: everyMonths ?? this.everyMonths,
      nextDue: nextDue ?? this.nextDue,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
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
    if (amountPiastres.present) {
      map['amount_piastres'] = Variable<int>(amountPiastres.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (subcategoryKey.present) {
      map['subcategory_key'] = Variable<String>(subcategoryKey.value);
    }
    if (everyMonths.present) {
      map['every_months'] = Variable<int>(everyMonths.value);
    }
    if (nextDue.present) {
      map['next_due'] = Variable<String>(nextDue.value);
    }
    if (remindDaysBefore.present) {
      map['remind_days_before'] = Variable<int>(remindDaysBefore.value);
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
    return (StringBuffer('RecurringBillsCompanion(')
          ..write('id: $id, ')
          ..write('nameAr: $nameAr, ')
          ..write('amountPiastres: $amountPiastres, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('subcategoryKey: $subcategoryKey, ')
          ..write('everyMonths: $everyMonths, ')
          ..write('nextDue: $nextDue, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $SubcategoriesTable subcategories = $SubcategoriesTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $CaptureGroupsTable captureGroups = $CaptureGroupsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $SalaryPeriodsTable salaryPeriods = $SalaryPeriodsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $ItemAliasesTable itemAliases = $ItemAliasesTable(this);
  late final $RecurringBillsTable recurringBills = $RecurringBillsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index entriesDate = Index(
    'entries_date',
    'CREATE INDEX entries_date ON entries (date)',
  );
  late final Index entriesCaptureGroupId = Index(
    'entries_capture_group_id',
    'CREATE INDEX entries_capture_group_id ON entries (capture_group_id)',
  );
  late final Index entriesDeletedAt = Index(
    'entries_deleted_at',
    'CREATE INDEX entries_deleted_at ON entries (deleted_at)',
  );
  late final Index entriesExternalId = Index(
    'entries_external_id',
    'CREATE UNIQUE INDEX entries_external_id ON entries (external_id) WHERE external_id IS NOT NULL',
  );
  late final Index salaryPeriodsExternalId = Index(
    'salary_periods_external_id',
    'CREATE UNIQUE INDEX salary_periods_external_id ON salary_periods (external_id) WHERE external_id IS NOT NULL',
  );
  late final Index attachmentsEntryId = Index(
    'attachments_entry_id',
    'CREATE INDEX attachments_entry_id ON attachments (entry_id)',
  );
  late final Index attachmentsCaptureGroupId = Index(
    'attachments_capture_group_id',
    'CREATE INDEX attachments_capture_group_id ON attachments (capture_group_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    subcategories,
    items,
    captureGroups,
    entries,
    salaryPeriods,
    attachments,
    itemAliases,
    recurringBills,
    appSettings,
    entriesDate,
    entriesCaptureGroupId,
    entriesDeletedAt,
    entriesExternalId,
    salaryPeriodsExternalId,
    attachmentsEntryId,
    attachmentsCaptureGroupId,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String key,
      required String labelAr,
      required String iconName,
      Value<String?> colorKey,
      Value<int> sortOrder,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> key,
      Value<String> labelAr,
      Value<String> iconName,
      Value<String?> colorKey,
      Value<int> sortOrder,
      Value<bool> archived,
      Value<int> rowid,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SubcategoriesTable, List<Subcategory>>
  _subcategoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subcategories,
    aliasName: 'categories__key__subcategories__category_key',
  );

  $$SubcategoriesTableProcessedTableManager get subcategoriesRefs {
    final manager = $$SubcategoriesTableTableManager(
      $_db,
      $_db.subcategories,
    ).filter((f) => f.categoryKey.key.sqlEquals($_itemColumn<String>('key')!));

    final cache = $_typedResult.readTableOrNull(_subcategoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: 'categories__key__items__category_key',
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.categoryKey.key.sqlEquals($_itemColumn<String>('key')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'categories__key__entries__category_key',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.categoryKey.key.sqlEquals($_itemColumn<String>('key')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringBillsTable, List<RecurringBill>>
  _recurringBillsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringBills,
    aliasName: 'categories__key__recurring_bills__category_key',
  );

  $$RecurringBillsTableProcessedTableManager get recurringBillsRefs {
    final manager = $$RecurringBillsTableTableManager(
      $_db,
      $_db.recurringBills,
    ).filter((f) => f.categoryKey.key.sqlEquals($_itemColumn<String>('key')!));

    final cache = $_typedResult.readTableOrNull(_recurringBillsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
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
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelAr => $composableBuilder(
    column: $table.labelAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> subcategoriesRefs(
    Expression<bool> Function($$SubcategoriesTableFilterComposer f) f,
  ) {
    final $$SubcategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableFilterComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringBillsRefs(
    Expression<bool> Function($$RecurringBillsTableFilterComposer f) f,
  ) {
    final $$RecurringBillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.recurringBills,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringBillsTableFilterComposer(
            $db: $db,
            $table: $db.recurringBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
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
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelAr => $composableBuilder(
    column: $table.labelAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get colorKey =>
      $composableBuilder(column: $table.colorKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> subcategoriesRefs<T extends Object>(
    Expression<T> Function($$SubcategoriesTableAnnotationComposer a) f,
  ) {
    final $$SubcategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recurringBillsRefs<T extends Object>(
    Expression<T> Function($$RecurringBillsTableAnnotationComposer a) f,
  ) {
    final $$RecurringBillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.recurringBills,
      getReferencedColumn: (t) => t.categoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringBillsTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function({
            bool subcategoriesRefs,
            bool itemsRefs,
            bool entriesRefs,
            bool recurringBillsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> labelAr = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<String?> colorKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                key: key,
                labelAr: labelAr,
                iconName: iconName,
                colorKey: colorKey,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String labelAr,
                required String iconName,
                Value<String?> colorKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                key: key,
                labelAr: labelAr,
                iconName: iconName,
                colorKey: colorKey,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                subcategoriesRefs = false,
                itemsRefs = false,
                entriesRefs = false,
                recurringBillsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (subcategoriesRefs) db.subcategories,
                    if (itemsRefs) db.items,
                    if (entriesRefs) db.entries,
                    if (recurringBillsRefs) db.recurringBills,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (subcategoriesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Subcategory
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._subcategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).subcategoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                      if (itemsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Item
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._itemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).itemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                      if (entriesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Entry
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._entriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).entriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                      if (recurringBillsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          RecurringBill
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._recurringBillsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringBillsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function({
        bool subcategoriesRefs,
        bool itemsRefs,
        bool entriesRefs,
        bool recurringBillsRefs,
      })
    >;
typedef $$SubcategoriesTableCreateCompanionBuilder =
    SubcategoriesCompanion Function({
      required String key,
      required String categoryKey,
      required String labelAr,
      required String iconName,
      Value<int> sortOrder,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$SubcategoriesTableUpdateCompanionBuilder =
    SubcategoriesCompanion Function({
      Value<String> key,
      Value<String> categoryKey,
      Value<String> labelAr,
      Value<String> iconName,
      Value<int> sortOrder,
      Value<bool> archived,
      Value<int> rowid,
    });

final class $$SubcategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $SubcategoriesTable, Subcategory> {
  $$SubcategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryKeyTable(_$AppDatabase db) =>
      db.categories.createAlias('subcategories__category_key__categories__key');

  $$CategoriesTableProcessedTableManager get categoryKey {
    final $_column = $_itemColumn<String>('category_key')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: 'subcategories__key__items__subcategory_key',
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager($_db, $_db.items).filter(
      (f) => f.subcategoryKey.key.sqlEquals($_itemColumn<String>('key')!),
    );

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'subcategories__key__entries__subcategory_key',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager($_db, $_db.entries).filter(
      (f) => f.subcategoryKey.key.sqlEquals($_itemColumn<String>('key')!),
    );

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringBillsTable, List<RecurringBill>>
  _recurringBillsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringBills,
    aliasName: 'subcategories__key__recurring_bills__subcategory_key',
  );

  $$RecurringBillsTableProcessedTableManager get recurringBillsRefs {
    final manager = $$RecurringBillsTableTableManager($_db, $_db.recurringBills)
        .filter(
          (f) => f.subcategoryKey.key.sqlEquals($_itemColumn<String>('key')!),
        );

    final cache = $_typedResult.readTableOrNull(_recurringBillsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubcategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelAr => $composableBuilder(
    column: $table.labelAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringBillsRefs(
    Expression<bool> Function($$RecurringBillsTableFilterComposer f) f,
  ) {
    final $$RecurringBillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.recurringBills,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringBillsTableFilterComposer(
            $db: $db,
            $table: $db.recurringBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubcategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelAr => $composableBuilder(
    column: $table.labelAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubcategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubcategoriesTable> {
  $$SubcategoriesTableAnnotationComposer({
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

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recurringBillsRefs<T extends Object>(
    Expression<T> Function($$RecurringBillsTableAnnotationComposer a) f,
  ) {
    final $$RecurringBillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.recurringBills,
      getReferencedColumn: (t) => t.subcategoryKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringBillsTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubcategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubcategoriesTable,
          Subcategory,
          $$SubcategoriesTableFilterComposer,
          $$SubcategoriesTableOrderingComposer,
          $$SubcategoriesTableAnnotationComposer,
          $$SubcategoriesTableCreateCompanionBuilder,
          $$SubcategoriesTableUpdateCompanionBuilder,
          (Subcategory, $$SubcategoriesTableReferences),
          Subcategory,
          PrefetchHooks Function({
            bool categoryKey,
            bool itemsRefs,
            bool entriesRefs,
            bool recurringBillsRefs,
          })
        > {
  $$SubcategoriesTableTableManager(_$AppDatabase db, $SubcategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubcategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubcategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubcategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String> labelAr = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubcategoriesCompanion(
                key: key,
                categoryKey: categoryKey,
                labelAr: labelAr,
                iconName: iconName,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String categoryKey,
                required String labelAr,
                required String iconName,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubcategoriesCompanion.insert(
                key: key,
                categoryKey: categoryKey,
                labelAr: labelAr,
                iconName: iconName,
                sortOrder: sortOrder,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubcategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryKey = false,
                itemsRefs = false,
                entriesRefs = false,
                recurringBillsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemsRefs) db.items,
                    if (entriesRefs) db.entries,
                    if (recurringBillsRefs) db.recurringBills,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (categoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryKey,
                                    referencedTable:
                                        $$SubcategoriesTableReferences
                                            ._categoryKeyTable(db),
                                    referencedColumn:
                                        $$SubcategoriesTableReferences
                                            ._categoryKeyTable(db)
                                            .key,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemsRefs)
                        await $_getPrefetchedData<
                          Subcategory,
                          $SubcategoriesTable,
                          Item
                        >(
                          currentTable: table,
                          referencedTable: $$SubcategoriesTableReferences
                              ._itemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubcategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).itemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                      if (entriesRefs)
                        await $_getPrefetchedData<
                          Subcategory,
                          $SubcategoriesTable,
                          Entry
                        >(
                          currentTable: table,
                          referencedTable: $$SubcategoriesTableReferences
                              ._entriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubcategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).entriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                      if (recurringBillsRefs)
                        await $_getPrefetchedData<
                          Subcategory,
                          $SubcategoriesTable,
                          RecurringBill
                        >(
                          currentTable: table,
                          referencedTable: $$SubcategoriesTableReferences
                              ._recurringBillsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubcategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringBillsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryKey == item.key,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SubcategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubcategoriesTable,
      Subcategory,
      $$SubcategoriesTableFilterComposer,
      $$SubcategoriesTableOrderingComposer,
      $$SubcategoriesTableAnnotationComposer,
      $$SubcategoriesTableCreateCompanionBuilder,
      $$SubcategoriesTableUpdateCompanionBuilder,
      (Subcategory, $$SubcategoriesTableReferences),
      Subcategory,
      PrefetchHooks Function({
        bool categoryKey,
        bool itemsRefs,
        bool entriesRefs,
        bool recurringBillsRefs,
      })
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String nameAr,
      required String nameEn,
      required String categoryKey,
      Value<String?> subcategoryKey,
      Value<int?> defaultAmountPiastres,
      Value<String?> barcode,
      Value<int> useCount,
      Value<DateTime?> lastUsedAt,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> nameAr,
      Value<String> nameEn,
      Value<String> categoryKey,
      Value<String?> subcategoryKey,
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
      db.categories.createAlias('items__category_key__categories__key');

  $$CategoriesTableProcessedTableManager get categoryKey {
    final $_column = $_itemColumn<String>('category_key')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SubcategoriesTable _subcategoryKeyTable(_$AppDatabase db) => db
      .subcategories
      .createAlias('items__subcategory_key__subcategories__key');

  $$SubcategoriesTableProcessedTableManager? get subcategoryKey {
    final $_column = $_itemColumn<String>('subcategory_key');
    if ($_column == null) return null;
    final manager = $$SubcategoriesTableTableManager(
      $_db,
      $_db.subcategories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemAliasesTable, List<ItemAlias>>
  _itemAliasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemAliases,
    aliasName: 'items__id__item_aliases__item_id',
  );

  $$ItemAliasesTableProcessedTableManager get itemAliasesRefs {
    final manager = $$ItemAliasesTableTableManager(
      $_db,
      $_db.itemAliases,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemAliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultAmountPiastres => $composableBuilder(
    column: $table.defaultAmountPiastres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableFilterComposer get subcategoryKey {
    final $$SubcategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableFilterComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemAliasesRefs(
    Expression<bool> Function($$ItemAliasesTableFilterComposer f) f,
  ) {
    final $$ItemAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemAliases,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemAliasesTableFilterComposer(
            $db: $db,
            $table: $db.itemAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultAmountPiastres => $composableBuilder(
    column: $table.defaultAmountPiastres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableOrderingComposer get subcategoryKey {
    final $$SubcategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
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
    column: $table.defaultAmountPiastres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableAnnotationComposer get subcategoryKey {
    final $$SubcategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemAliasesRefs<T extends Object>(
    Expression<T> Function($$ItemAliasesTableAnnotationComposer a) f,
  ) {
    final $$ItemAliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemAliases,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemAliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.itemAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function({
            bool categoryKey,
            bool subcategoryKey,
            bool itemAliasesRefs,
          })
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nameAr = const Value.absent(),
                Value<String> nameEn = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String?> subcategoryKey = const Value.absent(),
                Value<int?> defaultAmountPiastres = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                nameAr: nameAr,
                nameEn: nameEn,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                defaultAmountPiastres: defaultAmountPiastres,
                barcode: barcode,
                useCount: useCount,
                lastUsedAt: lastUsedAt,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nameAr,
                required String nameEn,
                required String categoryKey,
                Value<String?> subcategoryKey = const Value.absent(),
                Value<int?> defaultAmountPiastres = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                nameAr: nameAr,
                nameEn: nameEn,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                defaultAmountPiastres: defaultAmountPiastres,
                barcode: barcode,
                useCount: useCount,
                lastUsedAt: lastUsedAt,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ItemsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryKey = false,
                subcategoryKey = false,
                itemAliasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemAliasesRefs) db.itemAliases,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (categoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryKey,
                                    referencedTable: $$ItemsTableReferences
                                        ._categoryKeyTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._categoryKeyTable(db)
                                        .key,
                                  )
                                  as T;
                        }
                        if (subcategoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.subcategoryKey,
                                    referencedTable: $$ItemsTableReferences
                                        ._subcategoryKeyTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._subcategoryKeyTable(db)
                                        .key,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemAliasesRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, ItemAlias>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._itemAliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).itemAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function({
        bool categoryKey,
        bool subcategoryKey,
        bool itemAliasesRefs,
      })
    >;
typedef $$CaptureGroupsTableCreateCompanionBuilder =
    CaptureGroupsCompanion Function({
      required String id,
      required String kind,
      required String status,
      Value<String?> rawText,
      Value<String?> cleanText,
      Value<String?> parsedBy,
      required String date,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CaptureGroupsTableUpdateCompanionBuilder =
    CaptureGroupsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> status,
      Value<String?> rawText,
      Value<String?> cleanText,
      Value<String?> parsedBy,
      Value<String> date,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CaptureGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $CaptureGroupsTable, CaptureGroup> {
  $$CaptureGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'capture_groups__id__entries__capture_group_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.captureGroupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'capture_groups__id__attachments__capture_group_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.captureGroupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CaptureGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $CaptureGroupsTable> {
  $$CaptureGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanText => $composableBuilder(
    column: $table.cleanText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parsedBy => $composableBuilder(
    column: $table.parsedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.captureGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.captureGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaptureGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $CaptureGroupsTable> {
  $$CaptureGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanText => $composableBuilder(
    column: $table.cleanText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedBy => $composableBuilder(
    column: $table.parsedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaptureGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CaptureGroupsTable> {
  $$CaptureGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get cleanText =>
      $composableBuilder(column: $table.cleanText, builder: (column) => column);

  GeneratedColumn<String> get parsedBy =>
      $composableBuilder(column: $table.parsedBy, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.captureGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.captureGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CaptureGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CaptureGroupsTable,
          CaptureGroup,
          $$CaptureGroupsTableFilterComposer,
          $$CaptureGroupsTableOrderingComposer,
          $$CaptureGroupsTableAnnotationComposer,
          $$CaptureGroupsTableCreateCompanionBuilder,
          $$CaptureGroupsTableUpdateCompanionBuilder,
          (CaptureGroup, $$CaptureGroupsTableReferences),
          CaptureGroup,
          PrefetchHooks Function({bool entriesRefs, bool attachmentsRefs})
        > {
  $$CaptureGroupsTableTableManager(_$AppDatabase db, $CaptureGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaptureGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaptureGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaptureGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<String?> cleanText = const Value.absent(),
                Value<String?> parsedBy = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CaptureGroupsCompanion(
                id: id,
                kind: kind,
                status: status,
                rawText: rawText,
                cleanText: cleanText,
                parsedBy: parsedBy,
                date: date,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String status,
                Value<String?> rawText = const Value.absent(),
                Value<String?> cleanText = const Value.absent(),
                Value<String?> parsedBy = const Value.absent(),
                required String date,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CaptureGroupsCompanion.insert(
                id: id,
                kind: kind,
                status: status,
                rawText: rawText,
                cleanText: cleanText,
                parsedBy: parsedBy,
                date: date,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CaptureGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({entriesRefs = false, attachmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (entriesRefs) db.entries,
                    if (attachmentsRefs) db.attachments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (entriesRefs)
                        await $_getPrefetchedData<
                          CaptureGroup,
                          $CaptureGroupsTable,
                          Entry
                        >(
                          currentTable: table,
                          referencedTable: $$CaptureGroupsTableReferences
                              ._entriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaptureGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).entriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.captureGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          CaptureGroup,
                          $CaptureGroupsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$CaptureGroupsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CaptureGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.captureGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CaptureGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CaptureGroupsTable,
      CaptureGroup,
      $$CaptureGroupsTableFilterComposer,
      $$CaptureGroupsTableOrderingComposer,
      $$CaptureGroupsTableAnnotationComposer,
      $$CaptureGroupsTableCreateCompanionBuilder,
      $$CaptureGroupsTableUpdateCompanionBuilder,
      (CaptureGroup, $$CaptureGroupsTableReferences),
      CaptureGroup,
      PrefetchHooks Function({bool entriesRefs, bool attachmentsRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String date,
      required int amountPiastres,
      required String categoryKey,
      Value<String?> subcategoryKey,
      Value<String?> itemId,
      Value<String> description,
      Value<String> paymentMethod,
      Value<String?> photoPath,
      Value<String> source,
      Value<String?> note,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> quantityMilli,
      Value<String?> unit,
      Value<int?> unitPricePiastres,
      Value<String?> captureGroupId,
      Value<String?> externalId,
      Value<String?> reference,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> date,
      Value<int> amountPiastres,
      Value<String> categoryKey,
      Value<String?> subcategoryKey,
      Value<String?> itemId,
      Value<String> description,
      Value<String> paymentMethod,
      Value<String?> photoPath,
      Value<String> source,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int?> quantityMilli,
      Value<String?> unit,
      Value<int?> unitPricePiastres,
      Value<String?> captureGroupId,
      Value<String?> externalId,
      Value<String?> reference,
      Value<int> rowid,
    });

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryKeyTable(_$AppDatabase db) =>
      db.categories.createAlias('entries__category_key__categories__key');

  $$CategoriesTableProcessedTableManager get categoryKey {
    final $_column = $_itemColumn<String>('category_key')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SubcategoriesTable _subcategoryKeyTable(_$AppDatabase db) => db
      .subcategories
      .createAlias('entries__subcategory_key__subcategories__key');

  $$SubcategoriesTableProcessedTableManager? get subcategoryKey {
    final $_column = $_itemColumn<String>('subcategory_key');
    if ($_column == null) return null;
    final manager = $$SubcategoriesTableTableManager(
      $_db,
      $_db.subcategories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CaptureGroupsTable _captureGroupIdTable(_$AppDatabase db) => db
      .captureGroups
      .createAlias('entries__capture_group_id__capture_groups__id');

  $$CaptureGroupsTableProcessedTableManager? get captureGroupId {
    final $_column = $_itemColumn<String>('capture_group_id');
    if ($_column == null) return null;
    final manager = $$CaptureGroupsTableTableManager(
      $_db,
      $_db.captureGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_captureGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'entries__id__attachments__entry_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantityMilli => $composableBuilder(
    column: $table.quantityMilli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPricePiastres => $composableBuilder(
    column: $table.unitPricePiastres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableFilterComposer get subcategoryKey {
    final $$SubcategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableFilterComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableFilterComposer get captureGroupId {
    final $$CaptureGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableFilterComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantityMilli => $composableBuilder(
    column: $table.quantityMilli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPricePiastres => $composableBuilder(
    column: $table.unitPricePiastres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableOrderingComposer get subcategoryKey {
    final $$SubcategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableOrderingComposer get captureGroupId {
    final $$CaptureGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
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
    column: $table.amountPiastres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

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

  GeneratedColumn<int> get quantityMilli => $composableBuilder(
    column: $table.quantityMilli,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get unitPricePiastres => $composableBuilder(
    column: $table.unitPricePiastres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableAnnotationComposer get subcategoryKey {
    final $$SubcategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableAnnotationComposer get captureGroupId {
    final $$CaptureGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function({
            bool categoryKey,
            bool subcategoryKey,
            bool captureGroupId,
            bool attachmentsRefs,
          })
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> amountPiastres = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String?> subcategoryKey = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> quantityMilli = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int?> unitPricePiastres = const Value.absent(),
                Value<String?> captureGroupId = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                date: date,
                amountPiastres: amountPiastres,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                itemId: itemId,
                description: description,
                paymentMethod: paymentMethod,
                photoPath: photoPath,
                source: source,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                quantityMilli: quantityMilli,
                unit: unit,
                unitPricePiastres: unitPricePiastres,
                captureGroupId: captureGroupId,
                externalId: externalId,
                reference: reference,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                required int amountPiastres,
                required String categoryKey,
                Value<String?> subcategoryKey = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int?> quantityMilli = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int?> unitPricePiastres = const Value.absent(),
                Value<String?> captureGroupId = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                date: date,
                amountPiastres: amountPiastres,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                itemId: itemId,
                description: description,
                paymentMethod: paymentMethod,
                photoPath: photoPath,
                source: source,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                quantityMilli: quantityMilli,
                unit: unit,
                unitPricePiastres: unitPricePiastres,
                captureGroupId: captureGroupId,
                externalId: externalId,
                reference: reference,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryKey = false,
                subcategoryKey = false,
                captureGroupId = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attachmentsRefs) db.attachments,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (categoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryKey,
                                    referencedTable: $$EntriesTableReferences
                                        ._categoryKeyTable(db),
                                    referencedColumn: $$EntriesTableReferences
                                        ._categoryKeyTable(db)
                                        .key,
                                  )
                                  as T;
                        }
                        if (subcategoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.subcategoryKey,
                                    referencedTable: $$EntriesTableReferences
                                        ._subcategoryKeyTable(db),
                                    referencedColumn: $$EntriesTableReferences
                                        ._subcategoryKeyTable(db)
                                        .key,
                                  )
                                  as T;
                        }
                        if (captureGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.captureGroupId,
                                    referencedTable: $$EntriesTableReferences
                                        ._captureGroupIdTable(db),
                                    referencedColumn: $$EntriesTableReferences
                                        ._captureGroupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Entry,
                          $EntriesTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$EntriesTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function({
        bool categoryKey,
        bool subcategoryKey,
        bool captureGroupId,
        bool attachmentsRefs,
      })
    >;
typedef $$SalaryPeriodsTableCreateCompanionBuilder =
    SalaryPeriodsCompanion Function({
      required String id,
      required String datePaid,
      required int amountPiastres,
      Value<String?> evidencePhotoPath,
      Value<String?> note,
      Value<String?> externalId,
      Value<int> rowid,
    });
typedef $$SalaryPeriodsTableUpdateCompanionBuilder =
    SalaryPeriodsCompanion Function({
      Value<String> id,
      Value<String> datePaid,
      Value<int> amountPiastres,
      Value<String?> evidencePhotoPath,
      Value<String?> note,
      Value<String?> externalId,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datePaid => $composableBuilder(
    column: $table.datePaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidencePhotoPath => $composableBuilder(
    column: $table.evidencePhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datePaid => $composableBuilder(
    column: $table.datePaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidencePhotoPath => $composableBuilder(
    column: $table.evidencePhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.amountPiastres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidencePhotoPath => $composableBuilder(
    column: $table.evidencePhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );
}

class $$SalaryPeriodsTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<_$AppDatabase, $SalaryPeriodsTable, SalaryPeriod>,
          ),
          SalaryPeriod,
          PrefetchHooks Function()
        > {
  $$SalaryPeriodsTableTableManager(_$AppDatabase db, $SalaryPeriodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalaryPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalaryPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalaryPeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> datePaid = const Value.absent(),
                Value<int> amountPiastres = const Value.absent(),
                Value<String?> evidencePhotoPath = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalaryPeriodsCompanion(
                id: id,
                datePaid: datePaid,
                amountPiastres: amountPiastres,
                evidencePhotoPath: evidencePhotoPath,
                note: note,
                externalId: externalId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String datePaid,
                required int amountPiastres,
                Value<String?> evidencePhotoPath = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalaryPeriodsCompanion.insert(
                id: id,
                datePaid: datePaid,
                amountPiastres: amountPiastres,
                evidencePhotoPath: evidencePhotoPath,
                note: note,
                externalId: externalId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalaryPeriodsTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<_$AppDatabase, $SalaryPeriodsTable, SalaryPeriod>,
      ),
      SalaryPeriod,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      Value<String?> entryId,
      Value<String?> captureGroupId,
      required String kind,
      Value<String?> path,
      Value<String?> body,
      Value<String?> transcript,
      Value<int?> durationMs,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String?> entryId,
      Value<String?> captureGroupId,
      Value<String> kind,
      Value<String?> path,
      Value<String?> body,
      Value<String?> transcript,
      Value<int?> durationMs,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _entryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('attachments__entry_id__entries__id');

  $$EntriesTableProcessedTableManager? get entryId {
    final $_column = $_itemColumn<String>('entry_id');
    if ($_column == null) return null;
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CaptureGroupsTable _captureGroupIdTable(_$AppDatabase db) => db
      .captureGroups
      .createAlias('attachments__capture_group_id__capture_groups__id');

  $$CaptureGroupsTableProcessedTableManager? get captureGroupId {
    final $_column = $_itemColumn<String>('capture_group_id');
    if ($_column == null) return null;
    final manager = $$CaptureGroupsTableTableManager(
      $_db,
      $_db.captureGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_captureGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableFilterComposer get captureGroupId {
    final $$CaptureGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableFilterComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableOrderingComposer get captureGroupId {
    final $$CaptureGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CaptureGroupsTableAnnotationComposer get captureGroupId {
    final $$CaptureGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.captureGroupId,
      referencedTable: $db.captureGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CaptureGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.captureGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool entryId, bool captureGroupId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String?> captureGroupId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                entryId: entryId,
                captureGroupId: captureGroupId,
                kind: kind,
                path: path,
                body: body,
                transcript: transcript,
                durationMs: durationMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> entryId = const Value.absent(),
                Value<String?> captureGroupId = const Value.absent(),
                required String kind,
                Value<String?> path = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                entryId: entryId,
                captureGroupId: captureGroupId,
                kind: kind,
                path: path,
                body: body,
                transcript: transcript,
                durationMs: durationMs,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false, captureGroupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$AttachmentsTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$AttachmentsTableReferences
                                    ._entryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (captureGroupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.captureGroupId,
                                referencedTable: $$AttachmentsTableReferences
                                    ._captureGroupIdTable(db),
                                referencedColumn: $$AttachmentsTableReferences
                                    ._captureGroupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool entryId, bool captureGroupId})
    >;
typedef $$ItemAliasesTableCreateCompanionBuilder =
    ItemAliasesCompanion Function({
      required String alias,
      required String itemId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ItemAliasesTableUpdateCompanionBuilder =
    ItemAliasesCompanion Function({
      Value<String> alias,
      Value<String> itemId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ItemAliasesTableReferences
    extends BaseReferences<_$AppDatabase, $ItemAliasesTable, ItemAlias> {
  $$ItemAliasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias('item_aliases__item_id__items__id');

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $ItemAliasesTable> {
  $$ItemAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemAliasesTable> {
  $$ItemAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemAliasesTable> {
  $$ItemAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemAliasesTable,
          ItemAlias,
          $$ItemAliasesTableFilterComposer,
          $$ItemAliasesTableOrderingComposer,
          $$ItemAliasesTableAnnotationComposer,
          $$ItemAliasesTableCreateCompanionBuilder,
          $$ItemAliasesTableUpdateCompanionBuilder,
          (ItemAlias, $$ItemAliasesTableReferences),
          ItemAlias,
          PrefetchHooks Function({bool itemId})
        > {
  $$ItemAliasesTableTableManager(_$AppDatabase db, $ItemAliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> alias = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemAliasesCompanion(
                alias: alias,
                itemId: itemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String alias,
                required String itemId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ItemAliasesCompanion.insert(
                alias: alias,
                itemId: itemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemAliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$ItemAliasesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$ItemAliasesTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemAliasesTable,
      ItemAlias,
      $$ItemAliasesTableFilterComposer,
      $$ItemAliasesTableOrderingComposer,
      $$ItemAliasesTableAnnotationComposer,
      $$ItemAliasesTableCreateCompanionBuilder,
      $$ItemAliasesTableUpdateCompanionBuilder,
      (ItemAlias, $$ItemAliasesTableReferences),
      ItemAlias,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$RecurringBillsTableCreateCompanionBuilder =
    RecurringBillsCompanion Function({
      required String id,
      required String nameAr,
      required int amountPiastres,
      required String categoryKey,
      Value<String?> subcategoryKey,
      Value<int> everyMonths,
      required String nextDue,
      Value<int> remindDaysBefore,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$RecurringBillsTableUpdateCompanionBuilder =
    RecurringBillsCompanion Function({
      Value<String> id,
      Value<String> nameAr,
      Value<int> amountPiastres,
      Value<String> categoryKey,
      Value<String?> subcategoryKey,
      Value<int> everyMonths,
      Value<String> nextDue,
      Value<int> remindDaysBefore,
      Value<bool> archived,
      Value<int> rowid,
    });

final class $$RecurringBillsTableReferences
    extends BaseReferences<_$AppDatabase, $RecurringBillsTable, RecurringBill> {
  $$RecurringBillsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryKeyTable(_$AppDatabase db) => db.categories
      .createAlias('recurring_bills__category_key__categories__key');

  $$CategoriesTableProcessedTableManager get categoryKey {
    final $_column = $_itemColumn<String>('category_key')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SubcategoriesTable _subcategoryKeyTable(_$AppDatabase db) => db
      .subcategories
      .createAlias('recurring_bills__subcategory_key__subcategories__key');

  $$SubcategoriesTableProcessedTableManager? get subcategoryKey {
    final $_column = $_itemColumn<String>('subcategory_key');
    if ($_column == null) return null;
    final manager = $$SubcategoriesTableTableManager(
      $_db,
      $_db.subcategories,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecurringBillsTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringBillsTable> {
  $$RecurringBillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryKey {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableFilterComposer get subcategoryKey {
    final $$SubcategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableFilterComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringBillsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringBillsTable> {
  $$RecurringBillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameAr => $composableBuilder(
    column: $table.nameAr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextDue => $composableBuilder(
    column: $table.nextDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryKey {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableOrderingComposer get subcategoryKey {
    final $$SubcategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringBillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringBillsTable> {
  $$RecurringBillsTableAnnotationComposer({
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

  GeneratedColumn<int> get amountPiastres => $composableBuilder(
    column: $table.amountPiastres,
    builder: (column) => column,
  );

  GeneratedColumn<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryKey {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryKey,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SubcategoriesTableAnnotationComposer get subcategoryKey {
    final $$SubcategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryKey,
      referencedTable: $db.subcategories,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubcategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.subcategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringBillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringBillsTable,
          RecurringBill,
          $$RecurringBillsTableFilterComposer,
          $$RecurringBillsTableOrderingComposer,
          $$RecurringBillsTableAnnotationComposer,
          $$RecurringBillsTableCreateCompanionBuilder,
          $$RecurringBillsTableUpdateCompanionBuilder,
          (RecurringBill, $$RecurringBillsTableReferences),
          RecurringBill,
          PrefetchHooks Function({bool categoryKey, bool subcategoryKey})
        > {
  $$RecurringBillsTableTableManager(
    _$AppDatabase db,
    $RecurringBillsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringBillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringBillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nameAr = const Value.absent(),
                Value<int> amountPiastres = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<String?> subcategoryKey = const Value.absent(),
                Value<int> everyMonths = const Value.absent(),
                Value<String> nextDue = const Value.absent(),
                Value<int> remindDaysBefore = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringBillsCompanion(
                id: id,
                nameAr: nameAr,
                amountPiastres: amountPiastres,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                everyMonths: everyMonths,
                nextDue: nextDue,
                remindDaysBefore: remindDaysBefore,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nameAr,
                required int amountPiastres,
                required String categoryKey,
                Value<String?> subcategoryKey = const Value.absent(),
                Value<int> everyMonths = const Value.absent(),
                required String nextDue,
                Value<int> remindDaysBefore = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringBillsCompanion.insert(
                id: id,
                nameAr: nameAr,
                amountPiastres: amountPiastres,
                categoryKey: categoryKey,
                subcategoryKey: subcategoryKey,
                everyMonths: everyMonths,
                nextDue: nextDue,
                remindDaysBefore: remindDaysBefore,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringBillsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({categoryKey = false, subcategoryKey = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (categoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryKey,
                                    referencedTable:
                                        $$RecurringBillsTableReferences
                                            ._categoryKeyTable(db),
                                    referencedColumn:
                                        $$RecurringBillsTableReferences
                                            ._categoryKeyTable(db)
                                            .key,
                                  )
                                  as T;
                        }
                        if (subcategoryKey) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.subcategoryKey,
                                    referencedTable:
                                        $$RecurringBillsTableReferences
                                            ._subcategoryKeyTable(db),
                                    referencedColumn:
                                        $$RecurringBillsTableReferences
                                            ._subcategoryKeyTable(db)
                                            .key,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$RecurringBillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringBillsTable,
      RecurringBill,
      $$RecurringBillsTableFilterComposer,
      $$RecurringBillsTableOrderingComposer,
      $$RecurringBillsTableAnnotationComposer,
      $$RecurringBillsTableCreateCompanionBuilder,
      $$RecurringBillsTableUpdateCompanionBuilder,
      (RecurringBill, $$RecurringBillsTableReferences),
      RecurringBill,
      PrefetchHooks Function({bool categoryKey, bool subcategoryKey})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$SubcategoriesTableTableManager get subcategories =>
      $$SubcategoriesTableTableManager(_db, _db.subcategories);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$CaptureGroupsTableTableManager get captureGroups =>
      $$CaptureGroupsTableTableManager(_db, _db.captureGroups);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$SalaryPeriodsTableTableManager get salaryPeriods =>
      $$SalaryPeriodsTableTableManager(_db, _db.salaryPeriods);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$ItemAliasesTableTableManager get itemAliases =>
      $$ItemAliasesTableTableManager(_db, _db.itemAliases);
  $$RecurringBillsTableTableManager get recurringBills =>
      $$RecurringBillsTableTableManager(_db, _db.recurringBills);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
