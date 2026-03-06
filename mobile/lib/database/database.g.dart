// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PeopleTable extends People with TableInfo<$PeopleTable, PeopleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedMeta = const VerificationMeta(
    'lastUsed',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsed = GeneratedColumn<DateTime>(
    'last_used',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
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
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    lastUsed,
    useCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('last_used')) {
      context.handle(
        _lastUsedMeta,
        lastUsed.isAcceptableOrUnknown(data['last_used']!, _lastUsedMeta),
      );
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeopleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      lastUsed:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_used'],
          )!,
      useCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}use_count'],
          )!,
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class PeopleData extends DataClass implements Insertable<PeopleData> {
  final int id;
  final String name;
  final int colorValue;
  final DateTime lastUsed;
  final int useCount;
  const PeopleData({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.lastUsed,
    required this.useCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['last_used'] = Variable<DateTime>(lastUsed);
    map['use_count'] = Variable<int>(useCount);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      lastUsed: Value(lastUsed),
      useCount: Value(useCount),
    );
  }

  factory PeopleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      lastUsed: serializer.fromJson<DateTime>(json['lastUsed']),
      useCount: serializer.fromJson<int>(json['useCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'lastUsed': serializer.toJson<DateTime>(lastUsed),
      'useCount': serializer.toJson<int>(useCount),
    };
  }

  PeopleData copyWith({
    int? id,
    String? name,
    int? colorValue,
    DateTime? lastUsed,
    int? useCount,
  }) => PeopleData(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    lastUsed: lastUsed ?? this.lastUsed,
    useCount: useCount ?? this.useCount,
  );
  PeopleData copyWithCompanion(PeopleCompanion data) {
    return PeopleData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('lastUsed: $lastUsed, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, lastUsed, useCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleData &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.lastUsed == this.lastUsed &&
          other.useCount == this.useCount);
}

class PeopleCompanion extends UpdateCompanion<PeopleData> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<DateTime> lastUsed;
  final Value<int> useCount;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.lastUsed = const Value.absent(),
    this.useCount = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    this.lastUsed = const Value.absent(),
    this.useCount = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<PeopleData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<DateTime>? lastUsed,
    Expression<int>? useCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (lastUsed != null) 'last_used': lastUsed,
      if (useCount != null) 'use_count': useCount,
    });
  }

  PeopleCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<DateTime>? lastUsed,
    Value<int>? useCount,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      lastUsed: lastUsed ?? this.lastUsed,
      useCount: useCount ?? this.useCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (lastUsed.present) {
      map['last_used'] = Variable<DateTime>(lastUsed.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('lastUsed: $lastUsed, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }
}

class $TutorialStatesTable extends TutorialStates
    with TableInfo<$TutorialStatesTable, TutorialState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TutorialStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tutorialKeyMeta = const VerificationMeta(
    'tutorialKey',
  );
  @override
  late final GeneratedColumn<String> tutorialKey = GeneratedColumn<String>(
    'tutorial_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _hasBeenSeenMeta = const VerificationMeta(
    'hasBeenSeen',
  );
  @override
  late final GeneratedColumn<bool> hasBeenSeen = GeneratedColumn<bool>(
    'has_been_seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_been_seen" IN (0, 1))',
    ),
  );
  static const VerificationMeta _lastShownDateMeta = const VerificationMeta(
    'lastShownDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastShownDate =
      GeneratedColumn<DateTime>(
        'last_shown_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tutorialKey,
    hasBeenSeen,
    lastShownDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tutorial_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<TutorialState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tutorial_key')) {
      context.handle(
        _tutorialKeyMeta,
        tutorialKey.isAcceptableOrUnknown(
          data['tutorial_key']!,
          _tutorialKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tutorialKeyMeta);
    }
    if (data.containsKey('has_been_seen')) {
      context.handle(
        _hasBeenSeenMeta,
        hasBeenSeen.isAcceptableOrUnknown(
          data['has_been_seen']!,
          _hasBeenSeenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasBeenSeenMeta);
    }
    if (data.containsKey('last_shown_date')) {
      context.handle(
        _lastShownDateMeta,
        lastShownDate.isAcceptableOrUnknown(
          data['last_shown_date']!,
          _lastShownDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TutorialState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TutorialState(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      tutorialKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tutorial_key'],
          )!,
      hasBeenSeen:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}has_been_seen'],
          )!,
      lastShownDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_shown_date'],
      ),
    );
  }

  @override
  $TutorialStatesTable createAlias(String alias) {
    return $TutorialStatesTable(attachedDatabase, alias);
  }
}

class TutorialState extends DataClass implements Insertable<TutorialState> {
  final int id;
  final String tutorialKey;
  final bool hasBeenSeen;
  final DateTime? lastShownDate;
  const TutorialState({
    required this.id,
    required this.tutorialKey,
    required this.hasBeenSeen,
    this.lastShownDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tutorial_key'] = Variable<String>(tutorialKey);
    map['has_been_seen'] = Variable<bool>(hasBeenSeen);
    if (!nullToAbsent || lastShownDate != null) {
      map['last_shown_date'] = Variable<DateTime>(lastShownDate);
    }
    return map;
  }

  TutorialStatesCompanion toCompanion(bool nullToAbsent) {
    return TutorialStatesCompanion(
      id: Value(id),
      tutorialKey: Value(tutorialKey),
      hasBeenSeen: Value(hasBeenSeen),
      lastShownDate:
          lastShownDate == null && nullToAbsent
              ? const Value.absent()
              : Value(lastShownDate),
    );
  }

  factory TutorialState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TutorialState(
      id: serializer.fromJson<int>(json['id']),
      tutorialKey: serializer.fromJson<String>(json['tutorialKey']),
      hasBeenSeen: serializer.fromJson<bool>(json['hasBeenSeen']),
      lastShownDate: serializer.fromJson<DateTime?>(json['lastShownDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tutorialKey': serializer.toJson<String>(tutorialKey),
      'hasBeenSeen': serializer.toJson<bool>(hasBeenSeen),
      'lastShownDate': serializer.toJson<DateTime?>(lastShownDate),
    };
  }

  TutorialState copyWith({
    int? id,
    String? tutorialKey,
    bool? hasBeenSeen,
    Value<DateTime?> lastShownDate = const Value.absent(),
  }) => TutorialState(
    id: id ?? this.id,
    tutorialKey: tutorialKey ?? this.tutorialKey,
    hasBeenSeen: hasBeenSeen ?? this.hasBeenSeen,
    lastShownDate:
        lastShownDate.present ? lastShownDate.value : this.lastShownDate,
  );
  TutorialState copyWithCompanion(TutorialStatesCompanion data) {
    return TutorialState(
      id: data.id.present ? data.id.value : this.id,
      tutorialKey:
          data.tutorialKey.present ? data.tutorialKey.value : this.tutorialKey,
      hasBeenSeen:
          data.hasBeenSeen.present ? data.hasBeenSeen.value : this.hasBeenSeen,
      lastShownDate:
          data.lastShownDate.present
              ? data.lastShownDate.value
              : this.lastShownDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TutorialState(')
          ..write('id: $id, ')
          ..write('tutorialKey: $tutorialKey, ')
          ..write('hasBeenSeen: $hasBeenSeen, ')
          ..write('lastShownDate: $lastShownDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tutorialKey, hasBeenSeen, lastShownDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TutorialState &&
          other.id == this.id &&
          other.tutorialKey == this.tutorialKey &&
          other.hasBeenSeen == this.hasBeenSeen &&
          other.lastShownDate == this.lastShownDate);
}

class TutorialStatesCompanion extends UpdateCompanion<TutorialState> {
  final Value<int> id;
  final Value<String> tutorialKey;
  final Value<bool> hasBeenSeen;
  final Value<DateTime?> lastShownDate;
  const TutorialStatesCompanion({
    this.id = const Value.absent(),
    this.tutorialKey = const Value.absent(),
    this.hasBeenSeen = const Value.absent(),
    this.lastShownDate = const Value.absent(),
  });
  TutorialStatesCompanion.insert({
    this.id = const Value.absent(),
    required String tutorialKey,
    required bool hasBeenSeen,
    this.lastShownDate = const Value.absent(),
  }) : tutorialKey = Value(tutorialKey),
       hasBeenSeen = Value(hasBeenSeen);
  static Insertable<TutorialState> custom({
    Expression<int>? id,
    Expression<String>? tutorialKey,
    Expression<bool>? hasBeenSeen,
    Expression<DateTime>? lastShownDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tutorialKey != null) 'tutorial_key': tutorialKey,
      if (hasBeenSeen != null) 'has_been_seen': hasBeenSeen,
      if (lastShownDate != null) 'last_shown_date': lastShownDate,
    });
  }

  TutorialStatesCompanion copyWith({
    Value<int>? id,
    Value<String>? tutorialKey,
    Value<bool>? hasBeenSeen,
    Value<DateTime?>? lastShownDate,
  }) {
    return TutorialStatesCompanion(
      id: id ?? this.id,
      tutorialKey: tutorialKey ?? this.tutorialKey,
      hasBeenSeen: hasBeenSeen ?? this.hasBeenSeen,
      lastShownDate: lastShownDate ?? this.lastShownDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tutorialKey.present) {
      map['tutorial_key'] = Variable<String>(tutorialKey.value);
    }
    if (hasBeenSeen.present) {
      map['has_been_seen'] = Variable<bool>(hasBeenSeen.value);
    }
    if (lastShownDate.present) {
      map['last_shown_date'] = Variable<DateTime>(lastShownDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TutorialStatesCompanion(')
          ..write('id: $id, ')
          ..write('tutorialKey: $tutorialKey, ')
          ..write('hasBeenSeen: $hasBeenSeen, ')
          ..write('lastShownDate: $lastShownDate')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTable extends UserPreferences
    with TableInfo<$UserPreferencesTable, UserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _showAllItemsMeta = const VerificationMeta(
    'showAllItems',
  );
  @override
  late final GeneratedColumn<bool> showAllItems = GeneratedColumn<bool>(
    'show_all_items',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_all_items" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showPersonItemsMeta = const VerificationMeta(
    'showPersonItems',
  );
  @override
  late final GeneratedColumn<bool> showPersonItems = GeneratedColumn<bool>(
    'show_person_items',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_person_items" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showBreakdownMeta = const VerificationMeta(
    'showBreakdown',
  );
  @override
  late final GeneratedColumn<bool> showBreakdown = GeneratedColumn<bool>(
    'show_breakdown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_breakdown" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    showAllItems,
    showPersonItems,
    showBreakdown,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('show_all_items')) {
      context.handle(
        _showAllItemsMeta,
        showAllItems.isAcceptableOrUnknown(
          data['show_all_items']!,
          _showAllItemsMeta,
        ),
      );
    }
    if (data.containsKey('show_person_items')) {
      context.handle(
        _showPersonItemsMeta,
        showPersonItems.isAcceptableOrUnknown(
          data['show_person_items']!,
          _showPersonItemsMeta,
        ),
      );
    }
    if (data.containsKey('show_breakdown')) {
      context.handle(
        _showBreakdownMeta,
        showBreakdown.isAcceptableOrUnknown(
          data['show_breakdown']!,
          _showBreakdownMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreference(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      showAllItems:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}show_all_items'],
          )!,
      showPersonItems:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}show_person_items'],
          )!,
      showBreakdown:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}show_breakdown'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $UserPreferencesTable createAlias(String alias) {
    return $UserPreferencesTable(attachedDatabase, alias);
  }
}

class UserPreference extends DataClass implements Insertable<UserPreference> {
  final int id;
  final bool showAllItems;
  final bool showPersonItems;
  final bool showBreakdown;
  final DateTime updatedAt;
  const UserPreference({
    required this.id,
    required this.showAllItems,
    required this.showPersonItems,
    required this.showBreakdown,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['show_all_items'] = Variable<bool>(showAllItems);
    map['show_person_items'] = Variable<bool>(showPersonItems);
    map['show_breakdown'] = Variable<bool>(showBreakdown);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      id: Value(id),
      showAllItems: Value(showAllItems),
      showPersonItems: Value(showPersonItems),
      showBreakdown: Value(showBreakdown),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreference(
      id: serializer.fromJson<int>(json['id']),
      showAllItems: serializer.fromJson<bool>(json['showAllItems']),
      showPersonItems: serializer.fromJson<bool>(json['showPersonItems']),
      showBreakdown: serializer.fromJson<bool>(json['showBreakdown']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'showAllItems': serializer.toJson<bool>(showAllItems),
      'showPersonItems': serializer.toJson<bool>(showPersonItems),
      'showBreakdown': serializer.toJson<bool>(showBreakdown),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreference copyWith({
    int? id,
    bool? showAllItems,
    bool? showPersonItems,
    bool? showBreakdown,
    DateTime? updatedAt,
  }) => UserPreference(
    id: id ?? this.id,
    showAllItems: showAllItems ?? this.showAllItems,
    showPersonItems: showPersonItems ?? this.showPersonItems,
    showBreakdown: showBreakdown ?? this.showBreakdown,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      id: data.id.present ? data.id.value : this.id,
      showAllItems:
          data.showAllItems.present
              ? data.showAllItems.value
              : this.showAllItems,
      showPersonItems:
          data.showPersonItems.present
              ? data.showPersonItems.value
              : this.showPersonItems,
      showBreakdown:
          data.showBreakdown.present
              ? data.showBreakdown.value
              : this.showBreakdown,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('id: $id, ')
          ..write('showAllItems: $showAllItems, ')
          ..write('showPersonItems: $showPersonItems, ')
          ..write('showBreakdown: $showBreakdown, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, showAllItems, showPersonItems, showBreakdown, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.id == this.id &&
          other.showAllItems == this.showAllItems &&
          other.showPersonItems == this.showPersonItems &&
          other.showBreakdown == this.showBreakdown &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<int> id;
  final Value<bool> showAllItems;
  final Value<bool> showPersonItems;
  final Value<bool> showBreakdown;
  final Value<DateTime> updatedAt;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.showAllItems = const Value.absent(),
    this.showPersonItems = const Value.absent(),
    this.showBreakdown = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.showAllItems = const Value.absent(),
    this.showPersonItems = const Value.absent(),
    this.showBreakdown = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserPreference> custom({
    Expression<int>? id,
    Expression<bool>? showAllItems,
    Expression<bool>? showPersonItems,
    Expression<bool>? showBreakdown,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (showAllItems != null) 'show_all_items': showAllItems,
      if (showPersonItems != null) 'show_person_items': showPersonItems,
      if (showBreakdown != null) 'show_breakdown': showBreakdown,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<int>? id,
    Value<bool>? showAllItems,
    Value<bool>? showPersonItems,
    Value<bool>? showBreakdown,
    Value<DateTime>? updatedAt,
  }) {
    return UserPreferencesCompanion(
      id: id ?? this.id,
      showAllItems: showAllItems ?? this.showAllItems,
      showPersonItems: showPersonItems ?? this.showPersonItems,
      showBreakdown: showBreakdown ?? this.showBreakdown,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (showAllItems.present) {
      map['show_all_items'] = Variable<bool>(showAllItems.value);
    }
    if (showPersonItems.present) {
      map['show_person_items'] = Variable<bool>(showPersonItems.value);
    }
    if (showBreakdown.present) {
      map['show_breakdown'] = Variable<bool>(showBreakdown.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('showAllItems: $showAllItems, ')
          ..write('showPersonItems: $showPersonItems, ')
          ..write('showBreakdown: $showBreakdown, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RecentBillsTable extends RecentBills
    with TableInfo<$RecentBillsTable, RecentBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentBillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _billNameMeta = const VerificationMeta(
    'billName',
  );
  @override
  late final GeneratedColumn<String> billName = GeneratedColumn<String>(
    'bill_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _participantsMeta = const VerificationMeta(
    'participants',
  );
  @override
  late final GeneratedColumn<String> participants = GeneratedColumn<String>(
    'participants',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantCountMeta = const VerificationMeta(
    'participantCount',
  );
  @override
  late final GeneratedColumn<int> participantCount = GeneratedColumn<int>(
    'participant_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipAmountMeta = const VerificationMeta(
    'tipAmount',
  );
  @override
  late final GeneratedColumn<double> tipAmount = GeneratedColumn<double>(
    'tip_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipPercentageMeta = const VerificationMeta(
    'tipPercentage',
  );
  @override
  late final GeneratedColumn<double> tipPercentage = GeneratedColumn<double>(
    'tip_percentage',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF2196F3),
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
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _shareUrlMeta = const VerificationMeta(
    'shareUrl',
  );
  @override
  late final GeneratedColumn<String> shareUrl = GeneratedColumn<String>(
    'share_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billName,
    participants,
    participantCount,
    total,
    date,
    subtotal,
    tax,
    tipAmount,
    tipPercentage,
    items,
    colorValue,
    createdAt,
    shareUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentBill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bill_name')) {
      context.handle(
        _billNameMeta,
        billName.isAcceptableOrUnknown(data['bill_name']!, _billNameMeta),
      );
    }
    if (data.containsKey('participants')) {
      context.handle(
        _participantsMeta,
        participants.isAcceptableOrUnknown(
          data['participants']!,
          _participantsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantsMeta);
    }
    if (data.containsKey('participant_count')) {
      context.handle(
        _participantCountMeta,
        participantCount.isAcceptableOrUnknown(
          data['participant_count']!,
          _participantCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantCountMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    } else if (isInserting) {
      context.missing(_taxMeta);
    }
    if (data.containsKey('tip_amount')) {
      context.handle(
        _tipAmountMeta,
        tipAmount.isAcceptableOrUnknown(data['tip_amount']!, _tipAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_tipAmountMeta);
    }
    if (data.containsKey('tip_percentage')) {
      context.handle(
        _tipPercentageMeta,
        tipPercentage.isAcceptableOrUnknown(
          data['tip_percentage']!,
          _tipPercentageMeta,
        ),
      );
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('share_url')) {
      context.handle(
        _shareUrlMeta,
        shareUrl.isAcceptableOrUnknown(data['share_url']!, _shareUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentBill(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      billName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}bill_name'],
          )!,
      participants:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}participants'],
          )!,
      participantCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}participant_count'],
          )!,
      total:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}total'],
          )!,
      date:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}date'],
          )!,
      subtotal:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}subtotal'],
          )!,
      tax:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}tax'],
          )!,
      tipAmount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}tip_amount'],
          )!,
      tipPercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tip_percentage'],
      ),
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      ),
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      shareUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_url'],
      ),
    );
  }

  @override
  $RecentBillsTable createAlias(String alias) {
    return $RecentBillsTable(attachedDatabase, alias);
  }
}

class RecentBill extends DataClass implements Insertable<RecentBill> {
  final int id;
  final String billName;
  final String participants;
  final int participantCount;
  final double total;
  final String date;
  final double subtotal;
  final double tax;
  final double tipAmount;
  final double? tipPercentage;
  final String? items;
  final int colorValue;
  final DateTime createdAt;
  final String? shareUrl;
  const RecentBill({
    required this.id,
    required this.billName,
    required this.participants,
    required this.participantCount,
    required this.total,
    required this.date,
    required this.subtotal,
    required this.tax,
    required this.tipAmount,
    this.tipPercentage,
    this.items,
    required this.colorValue,
    required this.createdAt,
    this.shareUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bill_name'] = Variable<String>(billName);
    map['participants'] = Variable<String>(participants);
    map['participant_count'] = Variable<int>(participantCount);
    map['total'] = Variable<double>(total);
    map['date'] = Variable<String>(date);
    map['subtotal'] = Variable<double>(subtotal);
    map['tax'] = Variable<double>(tax);
    map['tip_amount'] = Variable<double>(tipAmount);
    if (!nullToAbsent || tipPercentage != null) {
      map['tip_percentage'] = Variable<double>(tipPercentage);
    }
    if (!nullToAbsent || items != null) {
      map['items'] = Variable<String>(items);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || shareUrl != null) {
      map['share_url'] = Variable<String>(shareUrl);
    }
    return map;
  }

  RecentBillsCompanion toCompanion(bool nullToAbsent) {
    return RecentBillsCompanion(
      id: Value(id),
      billName: Value(billName),
      participants: Value(participants),
      participantCount: Value(participantCount),
      total: Value(total),
      date: Value(date),
      subtotal: Value(subtotal),
      tax: Value(tax),
      tipAmount: Value(tipAmount),
      tipPercentage:
          tipPercentage == null && nullToAbsent
              ? const Value.absent()
              : Value(tipPercentage),
      items:
          items == null && nullToAbsent ? const Value.absent() : Value(items),
      colorValue: Value(colorValue),
      createdAt: Value(createdAt),
      shareUrl:
          shareUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(shareUrl),
    );
  }

  factory RecentBill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentBill(
      id: serializer.fromJson<int>(json['id']),
      billName: serializer.fromJson<String>(json['billName']),
      participants: serializer.fromJson<String>(json['participants']),
      participantCount: serializer.fromJson<int>(json['participantCount']),
      total: serializer.fromJson<double>(json['total']),
      date: serializer.fromJson<String>(json['date']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      tax: serializer.fromJson<double>(json['tax']),
      tipAmount: serializer.fromJson<double>(json['tipAmount']),
      tipPercentage: serializer.fromJson<double?>(json['tipPercentage']),
      items: serializer.fromJson<String?>(json['items']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      shareUrl: serializer.fromJson<String?>(json['shareUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'billName': serializer.toJson<String>(billName),
      'participants': serializer.toJson<String>(participants),
      'participantCount': serializer.toJson<int>(participantCount),
      'total': serializer.toJson<double>(total),
      'date': serializer.toJson<String>(date),
      'subtotal': serializer.toJson<double>(subtotal),
      'tax': serializer.toJson<double>(tax),
      'tipAmount': serializer.toJson<double>(tipAmount),
      'tipPercentage': serializer.toJson<double?>(tipPercentage),
      'items': serializer.toJson<String?>(items),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'shareUrl': serializer.toJson<String?>(shareUrl),
    };
  }

  RecentBill copyWith({
    int? id,
    String? billName,
    String? participants,
    int? participantCount,
    double? total,
    String? date,
    double? subtotal,
    double? tax,
    double? tipAmount,
    Value<double?> tipPercentage = const Value.absent(),
    Value<String?> items = const Value.absent(),
    int? colorValue,
    DateTime? createdAt,
    Value<String?> shareUrl = const Value.absent(),
  }) => RecentBill(
    id: id ?? this.id,
    billName: billName ?? this.billName,
    participants: participants ?? this.participants,
    participantCount: participantCount ?? this.participantCount,
    total: total ?? this.total,
    date: date ?? this.date,
    subtotal: subtotal ?? this.subtotal,
    tax: tax ?? this.tax,
    tipAmount: tipAmount ?? this.tipAmount,
    tipPercentage:
        tipPercentage.present ? tipPercentage.value : this.tipPercentage,
    items: items.present ? items.value : this.items,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
    shareUrl: shareUrl.present ? shareUrl.value : this.shareUrl,
  );
  RecentBill copyWithCompanion(RecentBillsCompanion data) {
    return RecentBill(
      id: data.id.present ? data.id.value : this.id,
      billName: data.billName.present ? data.billName.value : this.billName,
      participants:
          data.participants.present
              ? data.participants.value
              : this.participants,
      participantCount:
          data.participantCount.present
              ? data.participantCount.value
              : this.participantCount,
      total: data.total.present ? data.total.value : this.total,
      date: data.date.present ? data.date.value : this.date,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      tax: data.tax.present ? data.tax.value : this.tax,
      tipAmount: data.tipAmount.present ? data.tipAmount.value : this.tipAmount,
      tipPercentage:
          data.tipPercentage.present
              ? data.tipPercentage.value
              : this.tipPercentage,
      items: data.items.present ? data.items.value : this.items,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      shareUrl: data.shareUrl.present ? data.shareUrl.value : this.shareUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentBill(')
          ..write('id: $id, ')
          ..write('billName: $billName, ')
          ..write('participants: $participants, ')
          ..write('participantCount: $participantCount, ')
          ..write('total: $total, ')
          ..write('date: $date, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('tipAmount: $tipAmount, ')
          ..write('tipPercentage: $tipPercentage, ')
          ..write('items: $items, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('shareUrl: $shareUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    billName,
    participants,
    participantCount,
    total,
    date,
    subtotal,
    tax,
    tipAmount,
    tipPercentage,
    items,
    colorValue,
    createdAt,
    shareUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentBill &&
          other.id == this.id &&
          other.billName == this.billName &&
          other.participants == this.participants &&
          other.participantCount == this.participantCount &&
          other.total == this.total &&
          other.date == this.date &&
          other.subtotal == this.subtotal &&
          other.tax == this.tax &&
          other.tipAmount == this.tipAmount &&
          other.tipPercentage == this.tipPercentage &&
          other.items == this.items &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt &&
          other.shareUrl == this.shareUrl);
}

class RecentBillsCompanion extends UpdateCompanion<RecentBill> {
  final Value<int> id;
  final Value<String> billName;
  final Value<String> participants;
  final Value<int> participantCount;
  final Value<double> total;
  final Value<String> date;
  final Value<double> subtotal;
  final Value<double> tax;
  final Value<double> tipAmount;
  final Value<double?> tipPercentage;
  final Value<String?> items;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  final Value<String?> shareUrl;
  const RecentBillsCompanion({
    this.id = const Value.absent(),
    this.billName = const Value.absent(),
    this.participants = const Value.absent(),
    this.participantCount = const Value.absent(),
    this.total = const Value.absent(),
    this.date = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.tax = const Value.absent(),
    this.tipAmount = const Value.absent(),
    this.tipPercentage = const Value.absent(),
    this.items = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.shareUrl = const Value.absent(),
  });
  RecentBillsCompanion.insert({
    this.id = const Value.absent(),
    this.billName = const Value.absent(),
    required String participants,
    required int participantCount,
    required double total,
    required String date,
    required double subtotal,
    required double tax,
    required double tipAmount,
    this.tipPercentage = const Value.absent(),
    this.items = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.shareUrl = const Value.absent(),
  }) : participants = Value(participants),
       participantCount = Value(participantCount),
       total = Value(total),
       date = Value(date),
       subtotal = Value(subtotal),
       tax = Value(tax),
       tipAmount = Value(tipAmount);
  static Insertable<RecentBill> custom({
    Expression<int>? id,
    Expression<String>? billName,
    Expression<String>? participants,
    Expression<int>? participantCount,
    Expression<double>? total,
    Expression<String>? date,
    Expression<double>? subtotal,
    Expression<double>? tax,
    Expression<double>? tipAmount,
    Expression<double>? tipPercentage,
    Expression<String>? items,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
    Expression<String>? shareUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billName != null) 'bill_name': billName,
      if (participants != null) 'participants': participants,
      if (participantCount != null) 'participant_count': participantCount,
      if (total != null) 'total': total,
      if (date != null) 'date': date,
      if (subtotal != null) 'subtotal': subtotal,
      if (tax != null) 'tax': tax,
      if (tipAmount != null) 'tip_amount': tipAmount,
      if (tipPercentage != null) 'tip_percentage': tipPercentage,
      if (items != null) 'items': items,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
      if (shareUrl != null) 'share_url': shareUrl,
    });
  }

  RecentBillsCompanion copyWith({
    Value<int>? id,
    Value<String>? billName,
    Value<String>? participants,
    Value<int>? participantCount,
    Value<double>? total,
    Value<String>? date,
    Value<double>? subtotal,
    Value<double>? tax,
    Value<double>? tipAmount,
    Value<double?>? tipPercentage,
    Value<String?>? items,
    Value<int>? colorValue,
    Value<DateTime>? createdAt,
    Value<String?>? shareUrl,
  }) {
    return RecentBillsCompanion(
      id: id ?? this.id,
      billName: billName ?? this.billName,
      participants: participants ?? this.participants,
      participantCount: participantCount ?? this.participantCount,
      total: total ?? this.total,
      date: date ?? this.date,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      tipAmount: tipAmount ?? this.tipAmount,
      tipPercentage: tipPercentage ?? this.tipPercentage,
      items: items ?? this.items,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      shareUrl: shareUrl ?? this.shareUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (billName.present) {
      map['bill_name'] = Variable<String>(billName.value);
    }
    if (participants.present) {
      map['participants'] = Variable<String>(participants.value);
    }
    if (participantCount.present) {
      map['participant_count'] = Variable<int>(participantCount.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (tipAmount.present) {
      map['tip_amount'] = Variable<double>(tipAmount.value);
    }
    if (tipPercentage.present) {
      map['tip_percentage'] = Variable<double>(tipPercentage.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (shareUrl.present) {
      map['share_url'] = Variable<String>(shareUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentBillsCompanion(')
          ..write('id: $id, ')
          ..write('billName: $billName, ')
          ..write('participants: $participants, ')
          ..write('participantCount: $participantCount, ')
          ..write('total: $total, ')
          ..write('date: $date, ')
          ..write('subtotal: $subtotal, ')
          ..write('tax: $tax, ')
          ..write('tipAmount: $tipAmount, ')
          ..write('tipPercentage: $tipPercentage, ')
          ..write('items: $items, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('shareUrl: $shareUrl')
          ..write(')'))
        .toString();
  }
}

class $TabsTable extends Tabs with TableInfo<$TabsTable, Tab> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _billIdsMeta = const VerificationMeta(
    'billIds',
  );
  @override
  late final GeneratedColumn<String> billIds = GeneratedColumn<String>(
    'bill_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _backendIdMeta = const VerificationMeta(
    'backendId',
  );
  @override
  late final GeneratedColumn<int> backendId = GeneratedColumn<int>(
    'backend_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTokenMeta = const VerificationMeta(
    'accessToken',
  );
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
    'access_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shareUrlMeta = const VerificationMeta(
    'shareUrl',
  );
  @override
  late final GeneratedColumn<String> shareUrl = GeneratedColumn<String>(
    'share_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finalizedMeta = const VerificationMeta(
    'finalized',
  );
  @override
  late final GeneratedColumn<bool> finalized = GeneratedColumn<bool>(
    'finalized',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("finalized" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _memberTokenMeta = const VerificationMeta(
    'memberToken',
  );
  @override
  late final GeneratedColumn<String> memberToken = GeneratedColumn<String>(
    'member_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isRemoteMeta = const VerificationMeta(
    'isRemote',
  );
  @override
  late final GeneratedColumn<bool> isRemote = GeneratedColumn<bool>(
    'is_remote',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_remote" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    billIds,
    backendId,
    accessToken,
    shareUrl,
    finalized,
    memberToken,
    role,
    isRemote,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tab> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('bill_ids')) {
      context.handle(
        _billIdsMeta,
        billIds.isAcceptableOrUnknown(data['bill_ids']!, _billIdsMeta),
      );
    }
    if (data.containsKey('backend_id')) {
      context.handle(
        _backendIdMeta,
        backendId.isAcceptableOrUnknown(data['backend_id']!, _backendIdMeta),
      );
    }
    if (data.containsKey('access_token')) {
      context.handle(
        _accessTokenMeta,
        accessToken.isAcceptableOrUnknown(
          data['access_token']!,
          _accessTokenMeta,
        ),
      );
    }
    if (data.containsKey('share_url')) {
      context.handle(
        _shareUrlMeta,
        shareUrl.isAcceptableOrUnknown(data['share_url']!, _shareUrlMeta),
      );
    }
    if (data.containsKey('finalized')) {
      context.handle(
        _finalizedMeta,
        finalized.isAcceptableOrUnknown(data['finalized']!, _finalizedMeta),
      );
    }
    if (data.containsKey('member_token')) {
      context.handle(
        _memberTokenMeta,
        memberToken.isAcceptableOrUnknown(
          data['member_token']!,
          _memberTokenMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('is_remote')) {
      context.handle(
        _isRemoteMeta,
        isRemote.isAcceptableOrUnknown(data['is_remote']!, _isRemoteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tab map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tab(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      billIds:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}bill_ids'],
          )!,
      backendId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backend_id'],
      ),
      accessToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_token'],
      ),
      shareUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_url'],
      ),
      finalized:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}finalized'],
          )!,
      memberToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_token'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      isRemote:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_remote'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $TabsTable createAlias(String alias) {
    return $TabsTable(attachedDatabase, alias);
  }
}

class Tab extends DataClass implements Insertable<Tab> {
  final int id;
  final String name;
  final String description;
  final String billIds;
  final int? backendId;
  final String? accessToken;
  final String? shareUrl;
  final bool finalized;
  final String? memberToken;
  final String? role;
  final bool isRemote;
  final DateTime createdAt;
  const Tab({
    required this.id,
    required this.name,
    required this.description,
    required this.billIds,
    this.backendId,
    this.accessToken,
    this.shareUrl,
    required this.finalized,
    this.memberToken,
    this.role,
    required this.isRemote,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['bill_ids'] = Variable<String>(billIds);
    if (!nullToAbsent || backendId != null) {
      map['backend_id'] = Variable<int>(backendId);
    }
    if (!nullToAbsent || accessToken != null) {
      map['access_token'] = Variable<String>(accessToken);
    }
    if (!nullToAbsent || shareUrl != null) {
      map['share_url'] = Variable<String>(shareUrl);
    }
    map['finalized'] = Variable<bool>(finalized);
    if (!nullToAbsent || memberToken != null) {
      map['member_token'] = Variable<String>(memberToken);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    map['is_remote'] = Variable<bool>(isRemote);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TabsCompanion toCompanion(bool nullToAbsent) {
    return TabsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      billIds: Value(billIds),
      backendId:
          backendId == null && nullToAbsent
              ? const Value.absent()
              : Value(backendId),
      accessToken:
          accessToken == null && nullToAbsent
              ? const Value.absent()
              : Value(accessToken),
      shareUrl:
          shareUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(shareUrl),
      finalized: Value(finalized),
      memberToken:
          memberToken == null && nullToAbsent
              ? const Value.absent()
              : Value(memberToken),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      isRemote: Value(isRemote),
      createdAt: Value(createdAt),
    );
  }

  factory Tab.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tab(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      billIds: serializer.fromJson<String>(json['billIds']),
      backendId: serializer.fromJson<int?>(json['backendId']),
      accessToken: serializer.fromJson<String?>(json['accessToken']),
      shareUrl: serializer.fromJson<String?>(json['shareUrl']),
      finalized: serializer.fromJson<bool>(json['finalized']),
      memberToken: serializer.fromJson<String?>(json['memberToken']),
      role: serializer.fromJson<String?>(json['role']),
      isRemote: serializer.fromJson<bool>(json['isRemote']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'billIds': serializer.toJson<String>(billIds),
      'backendId': serializer.toJson<int?>(backendId),
      'accessToken': serializer.toJson<String?>(accessToken),
      'shareUrl': serializer.toJson<String?>(shareUrl),
      'finalized': serializer.toJson<bool>(finalized),
      'memberToken': serializer.toJson<String?>(memberToken),
      'role': serializer.toJson<String?>(role),
      'isRemote': serializer.toJson<bool>(isRemote),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tab copyWith({
    int? id,
    String? name,
    String? description,
    String? billIds,
    Value<int?> backendId = const Value.absent(),
    Value<String?> accessToken = const Value.absent(),
    Value<String?> shareUrl = const Value.absent(),
    bool? finalized,
    Value<String?> memberToken = const Value.absent(),
    Value<String?> role = const Value.absent(),
    bool? isRemote,
    DateTime? createdAt,
  }) => Tab(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    billIds: billIds ?? this.billIds,
    backendId: backendId.present ? backendId.value : this.backendId,
    accessToken: accessToken.present ? accessToken.value : this.accessToken,
    shareUrl: shareUrl.present ? shareUrl.value : this.shareUrl,
    finalized: finalized ?? this.finalized,
    memberToken: memberToken.present ? memberToken.value : this.memberToken,
    role: role.present ? role.value : this.role,
    isRemote: isRemote ?? this.isRemote,
    createdAt: createdAt ?? this.createdAt,
  );
  Tab copyWithCompanion(TabsCompanion data) {
    return Tab(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      billIds: data.billIds.present ? data.billIds.value : this.billIds,
      backendId: data.backendId.present ? data.backendId.value : this.backendId,
      accessToken:
          data.accessToken.present ? data.accessToken.value : this.accessToken,
      shareUrl: data.shareUrl.present ? data.shareUrl.value : this.shareUrl,
      finalized: data.finalized.present ? data.finalized.value : this.finalized,
      memberToken:
          data.memberToken.present ? data.memberToken.value : this.memberToken,
      role: data.role.present ? data.role.value : this.role,
      isRemote: data.isRemote.present ? data.isRemote.value : this.isRemote,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tab(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('billIds: $billIds, ')
          ..write('backendId: $backendId, ')
          ..write('accessToken: $accessToken, ')
          ..write('shareUrl: $shareUrl, ')
          ..write('finalized: $finalized, ')
          ..write('memberToken: $memberToken, ')
          ..write('role: $role, ')
          ..write('isRemote: $isRemote, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    billIds,
    backendId,
    accessToken,
    shareUrl,
    finalized,
    memberToken,
    role,
    isRemote,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tab &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.billIds == this.billIds &&
          other.backendId == this.backendId &&
          other.accessToken == this.accessToken &&
          other.shareUrl == this.shareUrl &&
          other.finalized == this.finalized &&
          other.memberToken == this.memberToken &&
          other.role == this.role &&
          other.isRemote == this.isRemote &&
          other.createdAt == this.createdAt);
}

class TabsCompanion extends UpdateCompanion<Tab> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> billIds;
  final Value<int?> backendId;
  final Value<String?> accessToken;
  final Value<String?> shareUrl;
  final Value<bool> finalized;
  final Value<String?> memberToken;
  final Value<String?> role;
  final Value<bool> isRemote;
  final Value<DateTime> createdAt;
  const TabsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.billIds = const Value.absent(),
    this.backendId = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.shareUrl = const Value.absent(),
    this.finalized = const Value.absent(),
    this.memberToken = const Value.absent(),
    this.role = const Value.absent(),
    this.isRemote = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TabsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.billIds = const Value.absent(),
    this.backendId = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.shareUrl = const Value.absent(),
    this.finalized = const Value.absent(),
    this.memberToken = const Value.absent(),
    this.role = const Value.absent(),
    this.isRemote = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tab> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? billIds,
    Expression<int>? backendId,
    Expression<String>? accessToken,
    Expression<String>? shareUrl,
    Expression<bool>? finalized,
    Expression<String>? memberToken,
    Expression<String>? role,
    Expression<bool>? isRemote,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (billIds != null) 'bill_ids': billIds,
      if (backendId != null) 'backend_id': backendId,
      if (accessToken != null) 'access_token': accessToken,
      if (shareUrl != null) 'share_url': shareUrl,
      if (finalized != null) 'finalized': finalized,
      if (memberToken != null) 'member_token': memberToken,
      if (role != null) 'role': role,
      if (isRemote != null) 'is_remote': isRemote,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TabsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? billIds,
    Value<int?>? backendId,
    Value<String?>? accessToken,
    Value<String?>? shareUrl,
    Value<bool>? finalized,
    Value<String?>? memberToken,
    Value<String?>? role,
    Value<bool>? isRemote,
    Value<DateTime>? createdAt,
  }) {
    return TabsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      billIds: billIds ?? this.billIds,
      backendId: backendId ?? this.backendId,
      accessToken: accessToken ?? this.accessToken,
      shareUrl: shareUrl ?? this.shareUrl,
      finalized: finalized ?? this.finalized,
      memberToken: memberToken ?? this.memberToken,
      role: role ?? this.role,
      isRemote: isRemote ?? this.isRemote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (billIds.present) {
      map['bill_ids'] = Variable<String>(billIds.value);
    }
    if (backendId.present) {
      map['backend_id'] = Variable<int>(backendId.value);
    }
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (shareUrl.present) {
      map['share_url'] = Variable<String>(shareUrl.value);
    }
    if (finalized.present) {
      map['finalized'] = Variable<bool>(finalized.value);
    }
    if (memberToken.present) {
      map['member_token'] = Variable<String>(memberToken.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isRemote.present) {
      map['is_remote'] = Variable<bool>(isRemote.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('billIds: $billIds, ')
          ..write('backendId: $backendId, ')
          ..write('accessToken: $accessToken, ')
          ..write('shareUrl: $shareUrl, ')
          ..write('finalized: $finalized, ')
          ..write('memberToken: $memberToken, ')
          ..write('role: $role, ')
          ..write('isRemote: $isRemote, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PeopleGroupsTable extends PeopleGroups
    with TableInfo<$PeopleGroupsTable, PeopleGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSuggestedMeta = const VerificationMeta(
    'isSuggested',
  );
  @override
  late final GeneratedColumn<bool> isSuggested = GeneratedColumn<bool>(
    'is_suggested',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_suggested" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  static const VerificationMeta _lastUsedMeta = const VerificationMeta(
    'lastUsed',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsed = GeneratedColumn<DateTime>(
    'last_used',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: Constant(DateTime.now()),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    isSuggested,
    createdAt,
    lastUsed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('is_suggested')) {
      context.handle(
        _isSuggestedMeta,
        isSuggested.isAcceptableOrUnknown(
          data['is_suggested']!,
          _isSuggestedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_used')) {
      context.handle(
        _lastUsedMeta,
        lastUsed.isAcceptableOrUnknown(data['last_used']!, _lastUsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeopleGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleGroup(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      isSuggested:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_suggested'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      lastUsed:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_used'],
          )!,
    );
  }

  @override
  $PeopleGroupsTable createAlias(String alias) {
    return $PeopleGroupsTable(attachedDatabase, alias);
  }
}

class PeopleGroup extends DataClass implements Insertable<PeopleGroup> {
  final int id;
  final String name;
  final int colorValue;
  final bool isSuggested;
  final DateTime createdAt;
  final DateTime lastUsed;
  const PeopleGroup({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.isSuggested,
    required this.createdAt,
    required this.lastUsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['is_suggested'] = Variable<bool>(isSuggested);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_used'] = Variable<DateTime>(lastUsed);
    return map;
  }

  PeopleGroupsCompanion toCompanion(bool nullToAbsent) {
    return PeopleGroupsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      isSuggested: Value(isSuggested),
      createdAt: Value(createdAt),
      lastUsed: Value(lastUsed),
    );
  }

  factory PeopleGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      isSuggested: serializer.fromJson<bool>(json['isSuggested']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsed: serializer.fromJson<DateTime>(json['lastUsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'isSuggested': serializer.toJson<bool>(isSuggested),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsed': serializer.toJson<DateTime>(lastUsed),
    };
  }

  PeopleGroup copyWith({
    int? id,
    String? name,
    int? colorValue,
    bool? isSuggested,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) => PeopleGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    isSuggested: isSuggested ?? this.isSuggested,
    createdAt: createdAt ?? this.createdAt,
    lastUsed: lastUsed ?? this.lastUsed,
  );
  PeopleGroup copyWithCompanion(PeopleGroupsCompanion data) {
    return PeopleGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      isSuggested:
          data.isSuggested.present ? data.isSuggested.value : this.isSuggested,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('isSuggested: $isSuggested, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorValue, isSuggested, createdAt, lastUsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.isSuggested == this.isSuggested &&
          other.createdAt == this.createdAt &&
          other.lastUsed == this.lastUsed);
}

class PeopleGroupsCompanion extends UpdateCompanion<PeopleGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<bool> isSuggested;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUsed;
  const PeopleGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isSuggested = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
  });
  PeopleGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    this.isSuggested = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<PeopleGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<bool>? isSuggested,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (isSuggested != null) 'is_suggested': isSuggested,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsed != null) 'last_used': lastUsed,
    });
  }

  PeopleGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<bool>? isSuggested,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastUsed,
  }) {
    return PeopleGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isSuggested: isSuggested ?? this.isSuggested,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (isSuggested.present) {
      map['is_suggested'] = Variable<bool>(isSuggested.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsed.present) {
      map['last_used'] = Variable<DateTime>(lastUsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('isSuggested: $isSuggested, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }
}

class $PeopleGroupMembersTable extends PeopleGroupMembers
    with TableInfo<$PeopleGroupMembersTable, PeopleGroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleGroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people_groups (id)',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, groupId, personId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people_group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleGroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeopleGroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleGroupMember(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      groupId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}group_id'],
          )!,
      personId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}person_id'],
          )!,
    );
  }

  @override
  $PeopleGroupMembersTable createAlias(String alias) {
    return $PeopleGroupMembersTable(attachedDatabase, alias);
  }
}

class PeopleGroupMember extends DataClass
    implements Insertable<PeopleGroupMember> {
  final int id;
  final int groupId;
  final int personId;
  const PeopleGroupMember({
    required this.id,
    required this.groupId,
    required this.personId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<int>(groupId);
    map['person_id'] = Variable<int>(personId);
    return map;
  }

  PeopleGroupMembersCompanion toCompanion(bool nullToAbsent) {
    return PeopleGroupMembersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      personId: Value(personId),
    );
  }

  factory PeopleGroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleGroupMember(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int>(json['groupId']),
      personId: serializer.fromJson<int>(json['personId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int>(groupId),
      'personId': serializer.toJson<int>(personId),
    };
  }

  PeopleGroupMember copyWith({int? id, int? groupId, int? personId}) =>
      PeopleGroupMember(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        personId: personId ?? this.personId,
      );
  PeopleGroupMember copyWithCompanion(PeopleGroupMembersCompanion data) {
    return PeopleGroupMember(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      personId: data.personId.present ? data.personId.value : this.personId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroupMember(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('personId: $personId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, personId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleGroupMember &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.personId == this.personId);
}

class PeopleGroupMembersCompanion extends UpdateCompanion<PeopleGroupMember> {
  final Value<int> id;
  final Value<int> groupId;
  final Value<int> personId;
  const PeopleGroupMembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.personId = const Value.absent(),
  });
  PeopleGroupMembersCompanion.insert({
    this.id = const Value.absent(),
    required int groupId,
    required int personId,
  }) : groupId = Value(groupId),
       personId = Value(personId);
  static Insertable<PeopleGroupMember> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<int>? personId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (personId != null) 'person_id': personId,
    });
  }

  PeopleGroupMembersCompanion copyWith({
    Value<int>? id,
    Value<int>? groupId,
    Value<int>? personId,
  }) {
    return PeopleGroupMembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      personId: personId ?? this.personId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroupMembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('personId: $personId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $TutorialStatesTable tutorialStates = $TutorialStatesTable(this);
  late final $UserPreferencesTable userPreferences = $UserPreferencesTable(
    this,
  );
  late final $RecentBillsTable recentBills = $RecentBillsTable(this);
  late final $TabsTable tabs = $TabsTable(this);
  late final $PeopleGroupsTable peopleGroups = $PeopleGroupsTable(this);
  late final $PeopleGroupMembersTable peopleGroupMembers =
      $PeopleGroupMembersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    tutorialStates,
    userPreferences,
    recentBills,
    tabs,
    peopleGroups,
    peopleGroupMembers,
  ];
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      Value<DateTime> lastUsed,
      Value<int> useCount,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<DateTime> lastUsed,
      Value<int> useCount,
    });

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, PeopleData> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PeopleGroupMembersTable, List<PeopleGroupMember>>
  _peopleGroupMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.peopleGroupMembers,
        aliasName: $_aliasNameGenerator(
          db.people.id,
          db.peopleGroupMembers.personId,
        ),
      );

  $$PeopleGroupMembersTableProcessedTableManager get peopleGroupMembersRefs {
    final manager = $$PeopleGroupMembersTableTableManager(
      $_db,
      $_db.peopleGroupMembers,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _peopleGroupMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> peopleGroupMembersRefs(
    Expression<bool> Function($$PeopleGroupMembersTableFilterComposer f) f,
  ) {
    final $$PeopleGroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.peopleGroupMembers,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.peopleGroupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUsed =>
      $composableBuilder(column: $table.lastUsed, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  Expression<T> peopleGroupMembersRefs<T extends Object>(
    Expression<T> Function($$PeopleGroupMembersTableAnnotationComposer a) f,
  ) {
    final $$PeopleGroupMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.peopleGroupMembers,
          getReferencedColumn: (t) => t.personId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PeopleGroupMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.peopleGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PeopleData,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PeopleData, $$PeopleTableReferences),
          PeopleData,
          PrefetchHooks Function({bool peopleGroupMembersRefs})
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> lastUsed = const Value.absent(),
                Value<int> useCount = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                lastUsed: lastUsed,
                useCount: useCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                Value<DateTime> lastUsed = const Value.absent(),
                Value<int> useCount = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                lastUsed: lastUsed,
                useCount: useCount,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$PeopleTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({peopleGroupMembersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (peopleGroupMembersRefs) db.peopleGroupMembers,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (peopleGroupMembersRefs)
                    await $_getPrefetchedData<
                      PeopleData,
                      $PeopleTable,
                      PeopleGroupMember
                    >(
                      currentTable: table,
                      referencedTable: $$PeopleTableReferences
                          ._peopleGroupMembersRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$PeopleTableReferences(
                                db,
                                table,
                                p0,
                              ).peopleGroupMembersRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.personId == item.id,
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

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PeopleData,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PeopleData, $$PeopleTableReferences),
      PeopleData,
      PrefetchHooks Function({bool peopleGroupMembersRefs})
    >;
typedef $$TutorialStatesTableCreateCompanionBuilder =
    TutorialStatesCompanion Function({
      Value<int> id,
      required String tutorialKey,
      required bool hasBeenSeen,
      Value<DateTime?> lastShownDate,
    });
typedef $$TutorialStatesTableUpdateCompanionBuilder =
    TutorialStatesCompanion Function({
      Value<int> id,
      Value<String> tutorialKey,
      Value<bool> hasBeenSeen,
      Value<DateTime?> lastShownDate,
    });

class $$TutorialStatesTableFilterComposer
    extends Composer<_$AppDatabase, $TutorialStatesTable> {
  $$TutorialStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorialKey => $composableBuilder(
    column: $table.tutorialKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasBeenSeen => $composableBuilder(
    column: $table.hasBeenSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastShownDate => $composableBuilder(
    column: $table.lastShownDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TutorialStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TutorialStatesTable> {
  $$TutorialStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorialKey => $composableBuilder(
    column: $table.tutorialKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasBeenSeen => $composableBuilder(
    column: $table.hasBeenSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastShownDate => $composableBuilder(
    column: $table.lastShownDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TutorialStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TutorialStatesTable> {
  $$TutorialStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tutorialKey => $composableBuilder(
    column: $table.tutorialKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasBeenSeen => $composableBuilder(
    column: $table.hasBeenSeen,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastShownDate => $composableBuilder(
    column: $table.lastShownDate,
    builder: (column) => column,
  );
}

class $$TutorialStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TutorialStatesTable,
          TutorialState,
          $$TutorialStatesTableFilterComposer,
          $$TutorialStatesTableOrderingComposer,
          $$TutorialStatesTableAnnotationComposer,
          $$TutorialStatesTableCreateCompanionBuilder,
          $$TutorialStatesTableUpdateCompanionBuilder,
          (
            TutorialState,
            BaseReferences<_$AppDatabase, $TutorialStatesTable, TutorialState>,
          ),
          TutorialState,
          PrefetchHooks Function()
        > {
  $$TutorialStatesTableTableManager(
    _$AppDatabase db,
    $TutorialStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TutorialStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$TutorialStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TutorialStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tutorialKey = const Value.absent(),
                Value<bool> hasBeenSeen = const Value.absent(),
                Value<DateTime?> lastShownDate = const Value.absent(),
              }) => TutorialStatesCompanion(
                id: id,
                tutorialKey: tutorialKey,
                hasBeenSeen: hasBeenSeen,
                lastShownDate: lastShownDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tutorialKey,
                required bool hasBeenSeen,
                Value<DateTime?> lastShownDate = const Value.absent(),
              }) => TutorialStatesCompanion.insert(
                id: id,
                tutorialKey: tutorialKey,
                hasBeenSeen: hasBeenSeen,
                lastShownDate: lastShownDate,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TutorialStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TutorialStatesTable,
      TutorialState,
      $$TutorialStatesTableFilterComposer,
      $$TutorialStatesTableOrderingComposer,
      $$TutorialStatesTableAnnotationComposer,
      $$TutorialStatesTableCreateCompanionBuilder,
      $$TutorialStatesTableUpdateCompanionBuilder,
      (
        TutorialState,
        BaseReferences<_$AppDatabase, $TutorialStatesTable, TutorialState>,
      ),
      TutorialState,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableCreateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<int> id,
      Value<bool> showAllItems,
      Value<bool> showPersonItems,
      Value<bool> showBreakdown,
      Value<DateTime> updatedAt,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<int> id,
      Value<bool> showAllItems,
      Value<bool> showPersonItems,
      Value<bool> showBreakdown,
      Value<DateTime> updatedAt,
    });

class $$UserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showAllItems => $composableBuilder(
    column: $table.showAllItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showPersonItems => $composableBuilder(
    column: $table.showPersonItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showBreakdown => $composableBuilder(
    column: $table.showBreakdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showAllItems => $composableBuilder(
    column: $table.showAllItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showPersonItems => $composableBuilder(
    column: $table.showPersonItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showBreakdown => $composableBuilder(
    column: $table.showBreakdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTable> {
  $$UserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get showAllItems => $composableBuilder(
    column: $table.showAllItems,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showPersonItems => $composableBuilder(
    column: $table.showPersonItems,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showBreakdown => $composableBuilder(
    column: $table.showBreakdown,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTable,
          UserPreference,
          $$UserPreferencesTableFilterComposer,
          $$UserPreferencesTableOrderingComposer,
          $$UserPreferencesTableAnnotationComposer,
          $$UserPreferencesTableCreateCompanionBuilder,
          $$UserPreferencesTableUpdateCompanionBuilder,
          (
            UserPreference,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTable,
              UserPreference
            >,
          ),
          UserPreference,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$UserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UserPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$UserPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> showAllItems = const Value.absent(),
                Value<bool> showPersonItems = const Value.absent(),
                Value<bool> showBreakdown = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserPreferencesCompanion(
                id: id,
                showAllItems: showAllItems,
                showPersonItems: showPersonItems,
                showBreakdown: showBreakdown,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> showAllItems = const Value.absent(),
                Value<bool> showPersonItems = const Value.absent(),
                Value<bool> showBreakdown = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                id: id,
                showAllItems: showAllItems,
                showPersonItems: showPersonItems,
                showBreakdown: showBreakdown,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTable,
      UserPreference,
      $$UserPreferencesTableFilterComposer,
      $$UserPreferencesTableOrderingComposer,
      $$UserPreferencesTableAnnotationComposer,
      $$UserPreferencesTableCreateCompanionBuilder,
      $$UserPreferencesTableUpdateCompanionBuilder,
      (
        UserPreference,
        BaseReferences<_$AppDatabase, $UserPreferencesTable, UserPreference>,
      ),
      UserPreference,
      PrefetchHooks Function()
    >;
typedef $$RecentBillsTableCreateCompanionBuilder =
    RecentBillsCompanion Function({
      Value<int> id,
      Value<String> billName,
      required String participants,
      required int participantCount,
      required double total,
      required String date,
      required double subtotal,
      required double tax,
      required double tipAmount,
      Value<double?> tipPercentage,
      Value<String?> items,
      Value<int> colorValue,
      Value<DateTime> createdAt,
      Value<String?> shareUrl,
    });
typedef $$RecentBillsTableUpdateCompanionBuilder =
    RecentBillsCompanion Function({
      Value<int> id,
      Value<String> billName,
      Value<String> participants,
      Value<int> participantCount,
      Value<double> total,
      Value<String> date,
      Value<double> subtotal,
      Value<double> tax,
      Value<double> tipAmount,
      Value<double?> tipPercentage,
      Value<String?> items,
      Value<int> colorValue,
      Value<DateTime> createdAt,
      Value<String?> shareUrl,
    });

class $$RecentBillsTableFilterComposer
    extends Composer<_$AppDatabase, $RecentBillsTable> {
  $$RecentBillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billName => $composableBuilder(
    column: $table.billName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participants => $composableBuilder(
    column: $table.participants,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get participantCount => $composableBuilder(
    column: $table.participantCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tipAmount => $composableBuilder(
    column: $table.tipAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tipPercentage => $composableBuilder(
    column: $table.tipPercentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareUrl => $composableBuilder(
    column: $table.shareUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentBillsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentBillsTable> {
  $$RecentBillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billName => $composableBuilder(
    column: $table.billName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participants => $composableBuilder(
    column: $table.participants,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get participantCount => $composableBuilder(
    column: $table.participantCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tipAmount => $composableBuilder(
    column: $table.tipAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tipPercentage => $composableBuilder(
    column: $table.tipPercentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareUrl => $composableBuilder(
    column: $table.shareUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentBillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentBillsTable> {
  $$RecentBillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billName =>
      $composableBuilder(column: $table.billName, builder: (column) => column);

  GeneratedColumn<String> get participants => $composableBuilder(
    column: $table.participants,
    builder: (column) => column,
  );

  GeneratedColumn<int> get participantCount => $composableBuilder(
    column: $table.participantCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<double> get tipAmount =>
      $composableBuilder(column: $table.tipAmount, builder: (column) => column);

  GeneratedColumn<double> get tipPercentage => $composableBuilder(
    column: $table.tipPercentage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get shareUrl =>
      $composableBuilder(column: $table.shareUrl, builder: (column) => column);
}

class $$RecentBillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentBillsTable,
          RecentBill,
          $$RecentBillsTableFilterComposer,
          $$RecentBillsTableOrderingComposer,
          $$RecentBillsTableAnnotationComposer,
          $$RecentBillsTableCreateCompanionBuilder,
          $$RecentBillsTableUpdateCompanionBuilder,
          (
            RecentBill,
            BaseReferences<_$AppDatabase, $RecentBillsTable, RecentBill>,
          ),
          RecentBill,
          PrefetchHooks Function()
        > {
  $$RecentBillsTableTableManager(_$AppDatabase db, $RecentBillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RecentBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RecentBillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$RecentBillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> billName = const Value.absent(),
                Value<String> participants = const Value.absent(),
                Value<int> participantCount = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<double> tax = const Value.absent(),
                Value<double> tipAmount = const Value.absent(),
                Value<double?> tipPercentage = const Value.absent(),
                Value<String?> items = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> shareUrl = const Value.absent(),
              }) => RecentBillsCompanion(
                id: id,
                billName: billName,
                participants: participants,
                participantCount: participantCount,
                total: total,
                date: date,
                subtotal: subtotal,
                tax: tax,
                tipAmount: tipAmount,
                tipPercentage: tipPercentage,
                items: items,
                colorValue: colorValue,
                createdAt: createdAt,
                shareUrl: shareUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> billName = const Value.absent(),
                required String participants,
                required int participantCount,
                required double total,
                required String date,
                required double subtotal,
                required double tax,
                required double tipAmount,
                Value<double?> tipPercentage = const Value.absent(),
                Value<String?> items = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> shareUrl = const Value.absent(),
              }) => RecentBillsCompanion.insert(
                id: id,
                billName: billName,
                participants: participants,
                participantCount: participantCount,
                total: total,
                date: date,
                subtotal: subtotal,
                tax: tax,
                tipAmount: tipAmount,
                tipPercentage: tipPercentage,
                items: items,
                colorValue: colorValue,
                createdAt: createdAt,
                shareUrl: shareUrl,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentBillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentBillsTable,
      RecentBill,
      $$RecentBillsTableFilterComposer,
      $$RecentBillsTableOrderingComposer,
      $$RecentBillsTableAnnotationComposer,
      $$RecentBillsTableCreateCompanionBuilder,
      $$RecentBillsTableUpdateCompanionBuilder,
      (
        RecentBill,
        BaseReferences<_$AppDatabase, $RecentBillsTable, RecentBill>,
      ),
      RecentBill,
      PrefetchHooks Function()
    >;
typedef $$TabsTableCreateCompanionBuilder =
    TabsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> description,
      Value<String> billIds,
      Value<int?> backendId,
      Value<String?> accessToken,
      Value<String?> shareUrl,
      Value<bool> finalized,
      Value<String?> memberToken,
      Value<String?> role,
      Value<bool> isRemote,
      Value<DateTime> createdAt,
    });
typedef $$TabsTableUpdateCompanionBuilder =
    TabsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> description,
      Value<String> billIds,
      Value<int?> backendId,
      Value<String?> accessToken,
      Value<String?> shareUrl,
      Value<bool> finalized,
      Value<String?> memberToken,
      Value<String?> role,
      Value<bool> isRemote,
      Value<DateTime> createdAt,
    });

class $$TabsTableFilterComposer extends Composer<_$AppDatabase, $TabsTable> {
  $$TabsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billIds => $composableBuilder(
    column: $table.billIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backendId => $composableBuilder(
    column: $table.backendId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareUrl => $composableBuilder(
    column: $table.shareUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get finalized => $composableBuilder(
    column: $table.finalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberToken => $composableBuilder(
    column: $table.memberToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRemote => $composableBuilder(
    column: $table.isRemote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TabsTableOrderingComposer extends Composer<_$AppDatabase, $TabsTable> {
  $$TabsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billIds => $composableBuilder(
    column: $table.billIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backendId => $composableBuilder(
    column: $table.backendId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareUrl => $composableBuilder(
    column: $table.shareUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get finalized => $composableBuilder(
    column: $table.finalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberToken => $composableBuilder(
    column: $table.memberToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRemote => $composableBuilder(
    column: $table.isRemote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TabsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TabsTable> {
  $$TabsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get billIds =>
      $composableBuilder(column: $table.billIds, builder: (column) => column);

  GeneratedColumn<int> get backendId =>
      $composableBuilder(column: $table.backendId, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shareUrl =>
      $composableBuilder(column: $table.shareUrl, builder: (column) => column);

  GeneratedColumn<bool> get finalized =>
      $composableBuilder(column: $table.finalized, builder: (column) => column);

  GeneratedColumn<String> get memberToken => $composableBuilder(
    column: $table.memberToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isRemote =>
      $composableBuilder(column: $table.isRemote, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TabsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TabsTable,
          Tab,
          $$TabsTableFilterComposer,
          $$TabsTableOrderingComposer,
          $$TabsTableAnnotationComposer,
          $$TabsTableCreateCompanionBuilder,
          $$TabsTableUpdateCompanionBuilder,
          (Tab, BaseReferences<_$AppDatabase, $TabsTable, Tab>),
          Tab,
          PrefetchHooks Function()
        > {
  $$TabsTableTableManager(_$AppDatabase db, $TabsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TabsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TabsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$TabsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> billIds = const Value.absent(),
                Value<int?> backendId = const Value.absent(),
                Value<String?> accessToken = const Value.absent(),
                Value<String?> shareUrl = const Value.absent(),
                Value<bool> finalized = const Value.absent(),
                Value<String?> memberToken = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<bool> isRemote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TabsCompanion(
                id: id,
                name: name,
                description: description,
                billIds: billIds,
                backendId: backendId,
                accessToken: accessToken,
                shareUrl: shareUrl,
                finalized: finalized,
                memberToken: memberToken,
                role: role,
                isRemote: isRemote,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
                Value<String> billIds = const Value.absent(),
                Value<int?> backendId = const Value.absent(),
                Value<String?> accessToken = const Value.absent(),
                Value<String?> shareUrl = const Value.absent(),
                Value<bool> finalized = const Value.absent(),
                Value<String?> memberToken = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<bool> isRemote = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TabsCompanion.insert(
                id: id,
                name: name,
                description: description,
                billIds: billIds,
                backendId: backendId,
                accessToken: accessToken,
                shareUrl: shareUrl,
                finalized: finalized,
                memberToken: memberToken,
                role: role,
                isRemote: isRemote,
                createdAt: createdAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TabsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TabsTable,
      Tab,
      $$TabsTableFilterComposer,
      $$TabsTableOrderingComposer,
      $$TabsTableAnnotationComposer,
      $$TabsTableCreateCompanionBuilder,
      $$TabsTableUpdateCompanionBuilder,
      (Tab, BaseReferences<_$AppDatabase, $TabsTable, Tab>),
      Tab,
      PrefetchHooks Function()
    >;
typedef $$PeopleGroupsTableCreateCompanionBuilder =
    PeopleGroupsCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      Value<bool> isSuggested,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsed,
    });
typedef $$PeopleGroupsTableUpdateCompanionBuilder =
    PeopleGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<bool> isSuggested,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsed,
    });

final class $$PeopleGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleGroupsTable, PeopleGroup> {
  $$PeopleGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PeopleGroupMembersTable, List<PeopleGroupMember>>
  _peopleGroupMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.peopleGroupMembers,
        aliasName: $_aliasNameGenerator(
          db.peopleGroups.id,
          db.peopleGroupMembers.groupId,
        ),
      );

  $$PeopleGroupMembersTableProcessedTableManager get peopleGroupMembersRefs {
    final manager = $$PeopleGroupMembersTableTableManager(
      $_db,
      $_db.peopleGroupMembers,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _peopleGroupMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSuggested => $composableBuilder(
    column: $table.isSuggested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> peopleGroupMembersRefs(
    Expression<bool> Function($$PeopleGroupMembersTableFilterComposer f) f,
  ) {
    final $$PeopleGroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.peopleGroupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.peopleGroupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSuggested => $composableBuilder(
    column: $table.isSuggested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSuggested => $composableBuilder(
    column: $table.isSuggested,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsed =>
      $composableBuilder(column: $table.lastUsed, builder: (column) => column);

  Expression<T> peopleGroupMembersRefs<T extends Object>(
    Expression<T> Function($$PeopleGroupMembersTableAnnotationComposer a) f,
  ) {
    final $$PeopleGroupMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.peopleGroupMembers,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PeopleGroupMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.peopleGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PeopleGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleGroupsTable,
          PeopleGroup,
          $$PeopleGroupsTableFilterComposer,
          $$PeopleGroupsTableOrderingComposer,
          $$PeopleGroupsTableAnnotationComposer,
          $$PeopleGroupsTableCreateCompanionBuilder,
          $$PeopleGroupsTableUpdateCompanionBuilder,
          (PeopleGroup, $$PeopleGroupsTableReferences),
          PeopleGroup,
          PrefetchHooks Function({bool peopleGroupMembersRefs})
        > {
  $$PeopleGroupsTableTableManager(_$AppDatabase db, $PeopleGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PeopleGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PeopleGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$PeopleGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<bool> isSuggested = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsed = const Value.absent(),
              }) => PeopleGroupsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                isSuggested: isSuggested,
                createdAt: createdAt,
                lastUsed: lastUsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                Value<bool> isSuggested = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsed = const Value.absent(),
              }) => PeopleGroupsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                isSuggested: isSuggested,
                createdAt: createdAt,
                lastUsed: lastUsed,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$PeopleGroupsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({peopleGroupMembersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (peopleGroupMembersRefs) db.peopleGroupMembers,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (peopleGroupMembersRefs)
                    await $_getPrefetchedData<
                      PeopleGroup,
                      $PeopleGroupsTable,
                      PeopleGroupMember
                    >(
                      currentTable: table,
                      referencedTable: $$PeopleGroupsTableReferences
                          ._peopleGroupMembersRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$PeopleGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).peopleGroupMembersRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.groupId == item.id,
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

typedef $$PeopleGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleGroupsTable,
      PeopleGroup,
      $$PeopleGroupsTableFilterComposer,
      $$PeopleGroupsTableOrderingComposer,
      $$PeopleGroupsTableAnnotationComposer,
      $$PeopleGroupsTableCreateCompanionBuilder,
      $$PeopleGroupsTableUpdateCompanionBuilder,
      (PeopleGroup, $$PeopleGroupsTableReferences),
      PeopleGroup,
      PrefetchHooks Function({bool peopleGroupMembersRefs})
    >;
typedef $$PeopleGroupMembersTableCreateCompanionBuilder =
    PeopleGroupMembersCompanion Function({
      Value<int> id,
      required int groupId,
      required int personId,
    });
typedef $$PeopleGroupMembersTableUpdateCompanionBuilder =
    PeopleGroupMembersCompanion Function({
      Value<int> id,
      Value<int> groupId,
      Value<int> personId,
    });

final class $$PeopleGroupMembersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PeopleGroupMembersTable,
          PeopleGroupMember
        > {
  $$PeopleGroupMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeopleGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.peopleGroups.createAlias(
        $_aliasNameGenerator(db.peopleGroupMembers.groupId, db.peopleGroups.id),
      );

  $$PeopleGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$PeopleGroupsTableTableManager(
      $_db,
      $_db.peopleGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _personIdTable(_$AppDatabase db) => db.people.createAlias(
    $_aliasNameGenerator(db.peopleGroupMembers.personId, db.people.id),
  );

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PeopleGroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleGroupMembersTable> {
  $$PeopleGroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleGroupsTableFilterComposer get groupId {
    final $$PeopleGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableFilterComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeopleGroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleGroupMembersTable> {
  $$PeopleGroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleGroupsTableOrderingComposer get groupId {
    final $$PeopleGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeopleGroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleGroupMembersTable> {
  $$PeopleGroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$PeopleGroupsTableAnnotationComposer get groupId {
    final $$PeopleGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeopleGroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleGroupMembersTable,
          PeopleGroupMember,
          $$PeopleGroupMembersTableFilterComposer,
          $$PeopleGroupMembersTableOrderingComposer,
          $$PeopleGroupMembersTableAnnotationComposer,
          $$PeopleGroupMembersTableCreateCompanionBuilder,
          $$PeopleGroupMembersTableUpdateCompanionBuilder,
          (PeopleGroupMember, $$PeopleGroupMembersTableReferences),
          PeopleGroupMember,
          PrefetchHooks Function({bool groupId, bool personId})
        > {
  $$PeopleGroupMembersTableTableManager(
    _$AppDatabase db,
    $PeopleGroupMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PeopleGroupMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$PeopleGroupMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$PeopleGroupMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<int> personId = const Value.absent(),
              }) => PeopleGroupMembersCompanion(
                id: id,
                groupId: groupId,
                personId: personId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int groupId,
                required int personId,
              }) => PeopleGroupMembersCompanion.insert(
                id: id,
                groupId: groupId,
                personId: personId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$PeopleGroupMembersTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({groupId = false, personId = false}) {
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
                  dynamic
                >
              >(state) {
                if (groupId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.groupId,
                            referencedTable: $$PeopleGroupMembersTableReferences
                                ._groupIdTable(db),
                            referencedColumn:
                                $$PeopleGroupMembersTableReferences
                                    ._groupIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (personId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.personId,
                            referencedTable: $$PeopleGroupMembersTableReferences
                                ._personIdTable(db),
                            referencedColumn:
                                $$PeopleGroupMembersTableReferences
                                    ._personIdTable(db)
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

typedef $$PeopleGroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleGroupMembersTable,
      PeopleGroupMember,
      $$PeopleGroupMembersTableFilterComposer,
      $$PeopleGroupMembersTableOrderingComposer,
      $$PeopleGroupMembersTableAnnotationComposer,
      $$PeopleGroupMembersTableCreateCompanionBuilder,
      $$PeopleGroupMembersTableUpdateCompanionBuilder,
      (PeopleGroupMember, $$PeopleGroupMembersTableReferences),
      PeopleGroupMember,
      PrefetchHooks Function({bool groupId, bool personId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$TutorialStatesTableTableManager get tutorialStates =>
      $$TutorialStatesTableTableManager(_db, _db.tutorialStates);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
  $$RecentBillsTableTableManager get recentBills =>
      $$RecentBillsTableTableManager(_db, _db.recentBills);
  $$TabsTableTableManager get tabs => $$TabsTableTableManager(_db, _db.tabs);
  $$PeopleGroupsTableTableManager get peopleGroups =>
      $$PeopleGroupsTableTableManager(_db, _db.peopleGroups);
  $$PeopleGroupMembersTableTableManager get peopleGroupMembers =>
      $$PeopleGroupMembersTableTableManager(_db, _db.peopleGroupMembers);
}
