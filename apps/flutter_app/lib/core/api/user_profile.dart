// User identity and role metadata for API headers.
import 'package:flutter/material.dart';

enum UserRole { broker, consumer, admin }

extension UserRoleHeader on UserRole {
  String get headerValue => name;

  String displayNameFor(Locale locale) {
    final isEnglish = locale.languageCode == 'en';
    switch (this) {
      case UserRole.broker:
        return isEnglish ? 'Broker' : 'B端经纪人';
      case UserRole.consumer:
        return isEnglish ? 'Consumer' : 'C端家庭用户';
      case UserRole.admin:
        return isEnglish ? 'Admin' : '平台管理员';
    }
  }

  String get displayName => displayNameFor(const Locale('zh'));
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.role,
    required this.tenantId,
    required this.displayName,
  });

  final String userId;
  final UserRole role;
  final String tenantId;
  final String displayName;

  UserProfile copyWith({
    String? userId,
    UserRole? role,
    String? tenantId,
    String? displayName,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      displayName: displayName ?? this.displayName,
    );
  }

  static UserProfile fromAuthUser(AuthUser user) {
    return UserProfile(
      userId: user.id,
      role: user.role,
      tenantId: user.tenantId,
      displayName: user.name,
    );
  }
}

// Lightweight auth user model for login responses.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.tenantId,
  });

  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String tenantId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      role: UserRole.values.firstWhere(
        (role) => role.name == (json['role'] ?? 'consumer'),
        orElse: () => UserRole.consumer,
      ),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
    );
  }
}
