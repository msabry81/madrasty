import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

class SessionController extends ChangeNotifier {
  SessionController(this._repo) {
    _sub = _repo.idTokenChanges().listen(_onUser);
  }

  final AuthRepository _repo;
  late final StreamSubscription<User?> _sub;

  User? user;
  AppRole role = AppRole.none;
  bool ready = false;

  bool get isAdmin => role == AppRole.admin;
  // مستخدم مسجّل بلا claim بعد = طالب قيد التهيئة.
  String get homePath => isAdmin ? '/admin' : '/student';

  Future<void> _onUser(User? u) async {
    user = u;
    role = u == null ? AppRole.none : await _repo.roleOf(u);
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
