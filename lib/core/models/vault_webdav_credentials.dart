class VaultWebDavCredentials {
  const VaultWebDavCredentials({
    required this.url,
    required this.account,
    required this.appPassword,
  });

  final String url;
  final String account;
  final String appPassword;

  bool get hasAppPassword => appPassword.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
    'url': url,
    'account': account,
    'appPassword': appPassword,
  };

  factory VaultWebDavCredentials.fromJson(Map<String, Object?> json) {
    return VaultWebDavCredentials(
      url: json['url'] as String? ?? '',
      account: json['account'] as String? ?? '',
      appPassword: json['appPassword'] as String? ?? '',
    );
  }
}
