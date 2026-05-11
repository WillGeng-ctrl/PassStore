class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.title,
    required this.account,
    required this.password,
    required this.url,
    required this.notes,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.lastModifiedDeviceId,
    required this.fieldUpdatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String account;
  final String password;
  final String url;
  final String notes;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String lastModifiedDeviceId;
  final Map<String, DateTime> fieldUpdatedAt;

  factory VaultEntry.create({
    required String title,
    required String account,
    required String password,
    required String url,
    required String notes,
    required String categoryId,
    required DateTime now,
    String deviceId = 'local',
  }) {
    final fields = {
      'title': now,
      'account': now,
      'password': now,
      'url': now,
      'notes': now,
      'categoryId': now,
      'deletedAt': now,
    };
    return VaultEntry(
      id: 'entry-${now.microsecondsSinceEpoch}-${title.hashCode.abs()}',
      title: title,
      account: account,
      password: password,
      url: url,
      notes: notes,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      lastModifiedDeviceId: deviceId,
      fieldUpdatedAt: fields,
    );
  }

  bool get isDeleted => deletedAt != null;

  VaultEntry copyWith({
    String? id,
    String? title,
    String? account,
    String? password,
    String? url,
    String? notes,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
    int? revision,
    String? lastModifiedDeviceId,
    Map<String, DateTime>? fieldUpdatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      account: account ?? this.account,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
      revision: revision ?? this.revision,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
      fieldUpdatedAt: fieldUpdatedAt ?? this.fieldUpdatedAt,
    );
  }

  VaultEntry touch({
    required DateTime now,
    required Iterable<String> fields,
    String deviceId = 'local',
  }) {
    final nextFields = Map<String, DateTime>.from(fieldUpdatedAt);
    for (final field in fields) {
      nextFields[field] = now;
    }
    return copyWith(
      updatedAt: now,
      revision: revision + 1,
      lastModifiedDeviceId: deviceId,
      fieldUpdatedAt: nextFields,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'account': account,
        'password': password,
        'url': url,
        'notes': notes,
        'categoryId': categoryId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'revision': revision,
        'lastModifiedDeviceId': lastModifiedDeviceId,
        'fieldUpdatedAt': fieldUpdatedAt.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      };

  factory VaultEntry.fromJson(Map<String, Object?> json) {
    final fields = (json['fieldUpdatedAt']! as Map<String, Object?>).map(
      (key, value) => MapEntry(key, DateTime.parse(value! as String)),
    );
    return VaultEntry(
      id: json['id']! as String,
      title: json['title']! as String,
      account: json['account']! as String,
      password: json['password']! as String,
      url: json['url']! as String,
      notes: json['notes']! as String,
      categoryId: json['categoryId']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt']! as String),
      revision: json['revision']! as int,
      lastModifiedDeviceId: json['lastModifiedDeviceId']! as String,
      fieldUpdatedAt: fields,
    );
  }

  static const Object _sentinel = Object();
}
