import 'package:flutter/material.dart';

enum OperatorRole {
  admin,
  manager,
  operator;

  String get label {
    switch (this) {
      case OperatorRole.admin:
        return 'Admin / Owner';
      case OperatorRole.manager:
        return 'Supervisor / Manager';
      case OperatorRole.operator:
        return 'Counter Staff / Operator';
    }
  }

  IconData get icon {
    switch (this) {
      case OperatorRole.admin:
        return Icons.admin_panel_settings_rounded;
      case OperatorRole.manager:
        return Icons.supervisor_account_rounded;
      case OperatorRole.operator:
        return Icons.person_rounded;
    }
  }

  Color get color {
    switch (this) {
      case OperatorRole.admin:
        return const Color(0xFF6366F1); // Indigo
      case OperatorRole.manager:
        return const Color(0xFF0EA5E9); // Sky blue
      case OperatorRole.operator:
        return const Color(0xFF10B981); // Emerald
    }
  }
}

class KioskOperator {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final OperatorRole role;
  final String passwordHash; // Local stored password
  final String pin; // 4-digit quick unlock PIN
  final String kioskName;
  final String? kioskAddress;
  final String? merchantUpiVpa;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int avatarColorIndex;
  final String status; // 'active', 'suspended', 'deleted'
  final bool isSuspended;
  final DateTime? suspendedAt;
  final String? suspendedReason;
  final DateTime? deletedAt;

  const KioskOperator({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.role = OperatorRole.operator,
    required this.passwordHash,
    required this.pin,
    required this.kioskName,
    this.kioskAddress,
    this.merchantUpiVpa,
    required this.createdAt,
    this.lastLoginAt,
    this.avatarColorIndex = 0,
    this.status = 'active',
    this.isSuspended = false,
    this.suspendedAt,
    this.suspendedReason,
    this.deletedAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'OP';
  }

  KioskOperator copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    OperatorRole? role,
    String? passwordHash,
    String? pin,
    String? kioskName,
    String? kioskAddress,
    String? merchantUpiVpa,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? avatarColorIndex,
    String? status,
    bool? isSuspended,
    DateTime? suspendedAt,
    String? suspendedReason,
    DateTime? deletedAt,
  }) {
    return KioskOperator(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      pin: pin ?? this.pin,
      kioskName: kioskName ?? this.kioskName,
      kioskAddress: kioskAddress ?? this.kioskAddress,
      merchantUpiVpa: merchantUpiVpa ?? this.merchantUpiVpa,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      status: status ?? this.status,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'role': role.name,
      'passwordHash': passwordHash,
      'pin': pin,
      'kioskName': kioskName,
      'kioskAddress': kioskAddress,
      'merchantUpiVpa': merchantUpiVpa,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'avatarColorIndex': avatarColorIndex,
      'status': status,
      'isSuspended': isSuspended,
      'suspendedAt': suspendedAt?.toIso8601String(),
      'suspendedReason': suspendedReason,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory KioskOperator.fromJson(Map<String, dynamic> map) {
    return KioskOperator(
      id: map['id'] as String,
      fullName: map['fullName'] as String? ?? map['name'] as String? ?? 'Operator',
      phone: map['phone'] as String? ?? map['mobile'] as String? ?? '',
      email: map['email'] as String?,
      role: OperatorRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => OperatorRole.operator,
      ),
      passwordHash: map['passwordHash'] as String? ?? '',
      pin: map['pin'] as String? ?? '1234',
      kioskName: map['kioskName'] as String? ?? 'Dossier Kiosk',
      kioskAddress: map['kioskAddress'] as String?,
      merchantUpiVpa: map['merchantUpiVpa'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.parse(map['lastLoginAt'] as String) : null,
      avatarColorIndex: (map['avatarColorIndex'] as int?) ?? 0,
      status: map['status'] as String? ?? 'active',
      isSuspended: map['isSuspended'] as bool? ?? (map['is_suspended'] == 1),
      suspendedAt: map['suspendedAt'] != null
          ? DateTime.tryParse(map['suspendedAt'] as String)
          : (map['suspended_at'] != null ? DateTime.tryParse(map['suspended_at'] as String) : null),
      suspendedReason: map['suspendedReason'] as String? ?? map['suspended_reason'] as String?,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'] as String)
          : (map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at'] as String) : null),
    );
  }
}
