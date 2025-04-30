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
  @override
  List<GeneratedColumn> get $columns => [id, name, colorValue, lastUsed];
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
  const PeopleData({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.lastUsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['last_used'] = Variable<DateTime>(lastUsed);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      lastUsed: Value(lastUsed),
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
    };
  }

  PeopleData copyWith({
    int? id,
    String? name,
    int? colorValue,
    DateTime? lastUsed,
  }) => PeopleData(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    lastUsed: lastUsed ?? this.lastUsed,
  );
  PeopleData copyWithCompanion(PeopleCompanion data) {
    return PeopleData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, lastUsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleData &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.lastUsed == this.lastUsed);
}

class PeopleCompanion extends UpdateCompanion<PeopleData> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<DateTime> lastUsed;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.lastUsed = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    this.lastUsed = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<PeopleData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<DateTime>? lastUsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (lastUsed != null) 'last_used': lastUsed,
    });
  }

  PeopleCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<DateTime>? lastUsed,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
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
    if (lastUsed.present) {
      map['last_used'] = Variable<DateTime>(lastUsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('lastUsed: $lastUsed')
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
  static const VerificationMeta _includeItemsInShareMeta =
      const VerificationMeta('includeItemsInShare');
  @override
  late final GeneratedColumn<bool> includeItemsInShare = GeneratedColumn<bool>(
    'include_items_in_share',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_items_in_share" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _includePersonItemsInShareMeta =
      const VerificationMeta('includePersonItemsInShare');
  @override
  late final GeneratedColumn<bool> includePersonItemsInShare =
      GeneratedColumn<bool>(
        'include_person_items_in_share',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("include_person_items_in_share" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _hideBreakdownInShareMeta =
      const VerificationMeta('hideBreakdownInShare');
  @override
  late final GeneratedColumn<bool> hideBreakdownInShare = GeneratedColumn<bool>(
    'hide_breakdown_in_share',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hide_breakdown_in_share" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    includeItemsInShare,
    includePersonItemsInShare,
    hideBreakdownInShare,
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
    if (data.containsKey('include_items_in_share')) {
      context.handle(
        _includeItemsInShareMeta,
        includeItemsInShare.isAcceptableOrUnknown(
          data['include_items_in_share']!,
          _includeItemsInShareMeta,
        ),
      );
    }
    if (data.containsKey('include_person_items_in_share')) {
      context.handle(
        _includePersonItemsInShareMeta,
        includePersonItemsInShare.isAcceptableOrUnknown(
          data['include_person_items_in_share']!,
          _includePersonItemsInShareMeta,
        ),
      );
    }
    if (data.containsKey('hide_breakdown_in_share')) {
      context.handle(
        _hideBreakdownInShareMeta,
        hideBreakdownInShare.isAcceptableOrUnknown(
          data['hide_breakdown_in_share']!,
          _hideBreakdownInShareMeta,
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
      includeItemsInShare:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}include_items_in_share'],
          )!,
      includePersonItemsInShare:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}include_person_items_in_share'],
          )!,
      hideBreakdownInShare:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}hide_breakdown_in_share'],
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
  final bool includeItemsInShare;
  final bool includePersonItemsInShare;
  final bool hideBreakdownInShare;
  final DateTime updatedAt;
  const UserPreference({
    required this.id,
    required this.includeItemsInShare,
    required this.includePersonItemsInShare,
    required this.hideBreakdownInShare,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['include_items_in_share'] = Variable<bool>(includeItemsInShare);
    map['include_person_items_in_share'] = Variable<bool>(
      includePersonItemsInShare,
    );
    map['hide_breakdown_in_share'] = Variable<bool>(hideBreakdownInShare);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
      id: Value(id),
      includeItemsInShare: Value(includeItemsInShare),
      includePersonItemsInShare: Value(includePersonItemsInShare),
      hideBreakdownInShare: Value(hideBreakdownInShare),
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
      includeItemsInShare: serializer.fromJson<bool>(
        json['includeItemsInShare'],
      ),
      includePersonItemsInShare: serializer.fromJson<bool>(
        json['includePersonItemsInShare'],
      ),
      hideBreakdownInShare: serializer.fromJson<bool>(
        json['hideBreakdownInShare'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'includeItemsInShare': serializer.toJson<bool>(includeItemsInShare),
      'includePersonItemsInShare': serializer.toJson<bool>(
        includePersonItemsInShare,
      ),
      'hideBreakdownInShare': serializer.toJson<bool>(hideBreakdownInShare),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreference copyWith({
    int? id,
    bool? includeItemsInShare,
    bool? includePersonItemsInShare,
    bool? hideBreakdownInShare,
    DateTime? updatedAt,
  }) => UserPreference(
    id: id ?? this.id,
    includeItemsInShare: includeItemsInShare ?? this.includeItemsInShare,
    includePersonItemsInShare:
        includePersonItemsInShare ?? this.includePersonItemsInShare,
    hideBreakdownInShare: hideBreakdownInShare ?? this.hideBreakdownInShare,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreference copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreference(
      id: data.id.present ? data.id.value : this.id,
      includeItemsInShare:
          data.includeItemsInShare.present
              ? data.includeItemsInShare.value
              : this.includeItemsInShare,
      includePersonItemsInShare:
          data.includePersonItemsInShare.present
              ? data.includePersonItemsInShare.value
              : this.includePersonItemsInShare,
      hideBreakdownInShare:
          data.hideBreakdownInShare.present
              ? data.hideBreakdownInShare.value
              : this.hideBreakdownInShare,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreference(')
          ..write('id: $id, ')
          ..write('includeItemsInShare: $includeItemsInShare, ')
          ..write('includePersonItemsInShare: $includePersonItemsInShare, ')
          ..write('hideBreakdownInShare: $hideBreakdownInShare, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    includeItemsInShare,
    includePersonItemsInShare,
    hideBreakdownInShare,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreference &&
          other.id == this.id &&
          other.includeItemsInShare == this.includeItemsInShare &&
          other.includePersonItemsInShare == this.includePersonItemsInShare &&
          other.hideBreakdownInShare == this.hideBreakdownInShare &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreference> {
  final Value<int> id;
  final Value<bool> includeItemsInShare;
  final Value<bool> includePersonItemsInShare;
  final Value<bool> hideBreakdownInShare;
  final Value<DateTime> updatedAt;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.includeItemsInShare = const Value.absent(),
    this.includePersonItemsInShare = const Value.absent(),
    this.hideBreakdownInShare = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.includeItemsInShare = const Value.absent(),
    this.includePersonItemsInShare = const Value.absent(),
    this.hideBreakdownInShare = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<UserPreference> custom({
    Expression<int>? id,
    Expression<bool>? includeItemsInShare,
    Expression<bool>? includePersonItemsInShare,
    Expression<bool>? hideBreakdownInShare,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (includeItemsInShare != null)
        'include_items_in_share': includeItemsInShare,
      if (includePersonItemsInShare != null)
        'include_person_items_in_share': includePersonItemsInShare,
      if (hideBreakdownInShare != null)
        'hide_breakdown_in_share': hideBreakdownInShare,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<int>? id,
    Value<bool>? includeItemsInShare,
    Value<bool>? includePersonItemsInShare,
    Value<bool>? hideBreakdownInShare,
    Value<DateTime>? updatedAt,
  }) {
    return UserPreferencesCompanion(
      id: id ?? this.id,
      includeItemsInShare: includeItemsInShare ?? this.includeItemsInShare,
      includePersonItemsInShare:
          includePersonItemsInShare ?? this.includePersonItemsInShare,
      hideBreakdownInShare: hideBreakdownInShare ?? this.hideBreakdownInShare,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (includeItemsInShare.present) {
      map['include_items_in_share'] = Variable<bool>(includeItemsInShare.value);
    }
    if (includePersonItemsInShare.present) {
      map['include_person_items_in_share'] = Variable<bool>(
        includePersonItemsInShare.value,
      );
    }
    if (hideBreakdownInShare.present) {
      map['hide_breakdown_in_share'] = Variable<bool>(
        hideBreakdownInShare.value,
      );
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
          ..write('includeItemsInShare: $includeItemsInShare, ')
          ..write('includePersonItemsInShare: $includePersonItemsInShare, ')
          ..write('hideBreakdownInShare: $hideBreakdownInShare, ')
          ..write('updatedAt: $updatedAt')
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    tutorialStates,
    userPreferences,
  ];
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      Value<DateTime> lastUsed,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<DateTime> lastUsed,
    });

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
          (PeopleData, BaseReferences<_$AppDatabase, $PeopleTable, PeopleData>),
          PeopleData,
          PrefetchHooks Function()
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
              }) => PeopleCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                lastUsed: lastUsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                Value<DateTime> lastUsed = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                lastUsed: lastUsed,
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
      (PeopleData, BaseReferences<_$AppDatabase, $PeopleTable, PeopleData>),
      PeopleData,
      PrefetchHooks Function()
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
      Value<bool> includeItemsInShare,
      Value<bool> includePersonItemsInShare,
      Value<bool> hideBreakdownInShare,
      Value<DateTime> updatedAt,
    });
typedef $$UserPreferencesTableUpdateCompanionBuilder =
    UserPreferencesCompanion Function({
      Value<int> id,
      Value<bool> includeItemsInShare,
      Value<bool> includePersonItemsInShare,
      Value<bool> hideBreakdownInShare,
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

  ColumnFilters<bool> get includeItemsInShare => $composableBuilder(
    column: $table.includeItemsInShare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includePersonItemsInShare => $composableBuilder(
    column: $table.includePersonItemsInShare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hideBreakdownInShare => $composableBuilder(
    column: $table.hideBreakdownInShare,
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

  ColumnOrderings<bool> get includeItemsInShare => $composableBuilder(
    column: $table.includeItemsInShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includePersonItemsInShare => $composableBuilder(
    column: $table.includePersonItemsInShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hideBreakdownInShare => $composableBuilder(
    column: $table.hideBreakdownInShare,
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

  GeneratedColumn<bool> get includeItemsInShare => $composableBuilder(
    column: $table.includeItemsInShare,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includePersonItemsInShare => $composableBuilder(
    column: $table.includePersonItemsInShare,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hideBreakdownInShare => $composableBuilder(
    column: $table.hideBreakdownInShare,
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
                Value<bool> includeItemsInShare = const Value.absent(),
                Value<bool> includePersonItemsInShare = const Value.absent(),
                Value<bool> hideBreakdownInShare = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserPreferencesCompanion(
                id: id,
                includeItemsInShare: includeItemsInShare,
                includePersonItemsInShare: includePersonItemsInShare,
                hideBreakdownInShare: hideBreakdownInShare,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> includeItemsInShare = const Value.absent(),
                Value<bool> includePersonItemsInShare = const Value.absent(),
                Value<bool> hideBreakdownInShare = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserPreferencesCompanion.insert(
                id: id,
                includeItemsInShare: includeItemsInShare,
                includePersonItemsInShare: includePersonItemsInShare,
                hideBreakdownInShare: hideBreakdownInShare,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$TutorialStatesTableTableManager get tutorialStates =>
      $$TutorialStatesTableTableManager(_db, _db.tutorialStates);
  $$UserPreferencesTableTableManager get userPreferences =>
      $$UserPreferencesTableTableManager(_db, _db.userPreferences);
}
