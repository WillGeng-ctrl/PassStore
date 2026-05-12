class Category {
  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isBuiltIn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const websiteId = 'builtin-website';
  static const emailId = 'builtin-email';
  static const appId = 'builtin-app';
  static const gameId = 'builtin-game';
  static const otherId = 'builtin-other';

  static List<Category> builtIns(DateTime now) => [
    Category(
      id: websiteId,
      name: '网站',
      sortOrder: 0,
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: emailId,
      name: '邮箱',
      sortOrder: 1,
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: appId,
      name: '应用',
      sortOrder: 2,
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: gameId,
      name: '游戏',
      sortOrder: 3,
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: otherId,
      name: '其他',
      sortOrder: 4,
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  Category copyWith({
    String? id,
    String? name,
    int? sortOrder,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Category.fromJson(Map<String, Object?> json) => Category(
    id: json['id']! as String,
    name: json['name']! as String,
    sortOrder: json['sortOrder']! as int,
    isBuiltIn: json['isBuiltIn']! as bool,
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );
}
