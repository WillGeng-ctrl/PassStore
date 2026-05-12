import 'category.dart';
import 'vault_entry.dart';
import 'vault_webdav_credentials.dart';

class Vault {
  const Vault({
    required this.id,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModifiedDeviceId,
    required this.categories,
    required this.entries,
    this.webDavCredentials,
  });

  final String id;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedDeviceId;
  final List<Category> categories;
  final List<VaultEntry> entries;
  final VaultWebDavCredentials? webDavCredentials;

  Vault copyWith({
    String? id,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedDeviceId,
    List<Category>? categories,
    List<VaultEntry>? entries,
    Object? webDavCredentials = _sentinel,
  }) {
    return Vault(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
      categories: categories ?? this.categories,
      entries: entries ?? this.entries,
      webDavCredentials: identical(webDavCredentials, _sentinel)
          ? this.webDavCredentials
          : webDavCredentials as VaultWebDavCredentials?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastModifiedDeviceId': lastModifiedDeviceId,
    'categories': categories.map((category) => category.toJson()).toList(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'webDavCredentials': webDavCredentials?.toJson(),
  };

  factory Vault.fromJson(Map<String, Object?> json) {
    final webDavCredentialsJson = json['webDavCredentials'];
    final updatedAt = DateTime.parse(json['updatedAt']! as String);
    final categories = (json['categories']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(Category.fromJson)
        .toList();
    return Vault(
      id: json['id']! as String,
      revision: json['revision']! as int,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: updatedAt,
      lastModifiedDeviceId: json['lastModifiedDeviceId']! as String,
      categories: _normalizeBuiltInCategories(categories, updatedAt),
      entries: (json['entries']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(VaultEntry.fromJson)
          .toList(),
      webDavCredentials: webDavCredentialsJson == null
          ? null
          : VaultWebDavCredentials.fromJson(
              (webDavCredentialsJson as Map<Object?, Object?>).cast(),
            ),
    );
  }

  static List<Category> _normalizeBuiltInCategories(
    List<Category> categories,
    DateTime fallbackTimestamp,
  ) {
    final builtInIds = Category.builtIns(
      fallbackTimestamp,
    ).map((category) => category.id).toSet();
    final existingById = {
      for (final category in categories) category.id: category,
    };
    final builtIns = Category.builtIns(fallbackTimestamp).map((defaults) {
      final existing = existingById[defaults.id];
      return (existing ?? defaults).copyWith(
        name: defaults.name,
        sortOrder: defaults.sortOrder,
        isBuiltIn: true,
      );
    });
    final customCategories = categories.where(
      (category) => !builtInIds.contains(category.id),
    );
    return [...builtIns, ...customCategories];
  }

  static const Object _sentinel = Object();
}
