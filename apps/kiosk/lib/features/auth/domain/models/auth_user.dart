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
  final String status; // 'active', 'suspended', 'deleted'
  final bool isSuspended;
  final DateTime? suspendedAt;
  final String? suspendedReason;
  final DateTime? deletedAt;

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
    this.status = 'active',
    this.isSuspended = false,
    this.suspendedAt,
    this.suspendedReason,
    this.deletedAt,
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
    String? status,
    bool? isSuspended,
    DateTime? suspendedAt,
    String? suspendedReason,
    DateTime? deletedAt,
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
      status: status ?? this.status,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      deletedAt: deletedAt ?? this.deletedAt,
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
      status: json['status'] as String? ?? 'active',
      isSuspended: json['isSuspended'] as bool? ?? (json['is_suspended'] == 1),
      suspendedAt: json['suspendedAt'] != null
          ? DateTime.tryParse(json['suspendedAt'] as String)
          : (json['suspended_at'] != null ? DateTime.tryParse(json['suspended_at'] as String) : null),
      suspendedReason: json['suspendedReason'] as String? ?? json['suspended_reason'] as String?,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : (json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null),
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
      'status': status,
      'isSuspended': isSuspended,
      'suspendedAt': suspendedAt?.toIso8601String(),
      'suspendedReason': suspendedReason,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}
