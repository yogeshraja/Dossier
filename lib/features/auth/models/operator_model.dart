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
    };
  }

  factory KioskOperator.fromJson(Map<String, dynamic> map) {
    return KioskOperator(
      id: map['id'] as String,
      fullName: map['fullName'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      role: OperatorRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => OperatorRole.operator,
      ),
      passwordHash: map['passwordHash'] as String,
      pin: map['pin'] as String,
      kioskName: map['kioskName'] as String,
      kioskAddress: map['kioskAddress'] as String?,
      merchantUpiVpa: map['merchantUpiVpa'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.parse(map['lastLoginAt'] as String) : null,
      avatarColorIndex: (map['avatarColorIndex'] as int?) ?? 0,
    );
  }
}
