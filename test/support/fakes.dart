import 'dart:async';

import 'package:tether/features/auth/domain/auth_repository.dart';
import 'package:tether/features/profile/domain/profile.dart';
import 'package:tether/features/profile/domain/profile_repository.dart';

/// Repository auth palsu: tanpa server, dengan aliran status yang bisa diatur.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._userId});

  String? _userId;
  final _changes = StreamController<String?>.broadcast();

  /// Bila diisi, signIn/signUp/signOut melempar ini.
  AuthFailure? failure;
  Completer<void>? gate;
  SignUpOutcome signUpOutcome = SignUpOutcome.signedIn;

  final calls = <String>[];
  Map<String, String>? lastSignUp;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  /// Simulasi perubahan status dari luar (mis. sesi berakhir).
  void emit(String? id) {
    _userId = id;
    _changes.add(id);
  }

  Future<void> _maybeFail() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    await _maybeFail();
    emit('user-1');
  }

  @override
  Future<void> resetPassword({required String email}) async {
    calls.add('resetPassword:$email');
    await _maybeFail();
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp:$email');
    lastSignUp = {'email': email, 'displayName': displayName};
    await _maybeFail();
    if (signUpOutcome == SignUpOutcome.signedIn) emit('user-1');
    return signUpOutcome;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    await _maybeFail();
    emit(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? profile})
    : profile =
          profile ??
          const Profile(
            id: 'user-1',
            displayName: 'Rina Wati',
            color: '#0F766E',
          );

  Profile profile;
  ProfileFailure? failure;
  final updates = <Map<String, String?>>[];

  @override
  Future<Profile> fetchOwn() async {
    if (failure != null) throw failure!;
    return profile;
  }

  @override
  Future<Profile> updateOwn({String? displayName, String? color}) async {
    updates.add({'displayName': displayName, 'color': color});
    if (failure != null) throw failure!;
    profile = profile.copyWith(displayName: displayName, color: color);
    return profile;
  }
}
