import 'category.dart';
import 'vault_entry.dart';

class Vault {
  const Vault({
    required this.id,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModifiedDeviceId,
    required this.categories,
    required this.entries,
  });

  final String id;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedDeviceId;
  final List<Category> categories;
  final List<VaultEntry> entries;

  Vault copyWith({
    String? id,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedDeviceId,
    List<Category>? categories,
    List<VaultEntry>? entries,
  }) {
    return Vault(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
      categories: categories ?? this.categories,
      entries: entries ?? this.entries,
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
      };

  factory Vault.fromJson(Map<String, Object?> json) => Vault(
        id: json['id']! as String,
        revision: json['revision']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        lastModifiedDeviceId: json['lastModifiedDeviceId']! as String,
        categories: (json['categories']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(Category.fromJson)
            .toList(),
        entries: (json['entries']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(VaultEntry.fromJson)
            .toList(),
      );
}
