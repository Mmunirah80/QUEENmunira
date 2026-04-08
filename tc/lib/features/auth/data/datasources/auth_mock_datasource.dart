import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

const String _keyMockUser = 'mock_user_json';

class AuthMockDataSource implements AuthRemoteDataSource {
  UserModel? _currentUser;

  Future<void> _persistUser(UserModel? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_keyMockUser);
    } else {
      await prefs.setString(_keyMockUser, jsonEncode(user.toJson()));
    }
  }

  Future<UserModel?> _restoreUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyMockUser);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel> login(String email, String password, [AppRole? role]) async {
    await Future.delayed(AppConstants.mockDelay);

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final isChef = (role ?? AppRole.chef) == AppRole.chef;
    _currentUser = UserModel(
      id: 'user_${Random().nextInt(10000)}',
      email: email,
      name: email.split('@')[0],
      phone: '+1234567890',
      isVerified: true,
      role: role ?? AppRole.chef,
      chefAccessLevel: isChef ? ChefAccessLevel.fullAccess : null,
      chefApprovalStatus: isChef ? ChefApprovalStatus.approved : null,
    );
    await _persistUser(_currentUser);
    return _currentUser!;
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    await Future.delayed(AppConstants.mockDelay);

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw Exception('All fields are required');
    }
    if (!email.isValidEmail) {
      throw Exception('Invalid email format');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final effectiveRole = role ?? AppRole.customer;
    _currentUser = UserModel(
      id: 'user_${Random().nextInt(10000)}',
      email: email,
      name: name,
      phone: phone,
      role: effectiveRole,
      chefAccessLevel:
          effectiveRole == AppRole.chef ? ChefAccessLevel.partialAccess : null,
      chefApprovalStatus:
          effectiveRole == AppRole.chef ? ChefApprovalStatus.pending : null,
    );
    await _persistUser(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    await _persistUser(null);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_currentUser != null) return _currentUser;
    _currentUser = await _restoreUser();
    return _currentUser;
  }
}

extension StringValidation on String {
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }
}
