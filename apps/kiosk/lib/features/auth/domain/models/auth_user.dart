enum AuthProviderType { email, mobile, google, offline }

class AuthUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final AuthProviderType provider;
  final String role;
  final bool hasKiosk;
  final String? kioskId;

  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.provider = AuthProviderType.email,
    this.role = 'admin',
    this.hasKiosk = false,
    this.kioskId,
  });

  AuthUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    AuthProviderType? provider,
    String? role,
    bool? hasKiosk,
    String? kioskId,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      provider: provider ?? this.provider,
      role: role ?? this.role,
      hasKiosk: hasKiosk ?? this.hasKiosk,
      kioskId: kioskId ?? this.kioskId,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final provStr = json['authProvider'] as String? ?? 'email';
    final provider = provStr == 'google'
        ? AuthProviderType.google
        : (provStr == 'mobile' ? AuthProviderType.mobile : AuthProviderType.email);

    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'User',
      email: json['email'] as String?,
      phone: json['mobile'] as String? ?? json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      provider: provider,
      role: json['role'] as String? ?? 'admin',
      hasKiosk: json['hasKiosk'] as bool? ?? false,
      kioskId: json['kioskId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': phone,
      'avatarUrl': avatarUrl,
      'authProvider': provider.name,
      'role': role,
      'hasKiosk': hasKiosk,
      'kioskId': kioskId,
    };
  }
}
