import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/auth/domain/auth_validators.dart';

void main() {
  test('email valid', () {
    expect(AuthValidators.email('a@b.co'), isNull);
    expect(AuthValidators.email('  rina@contoh.com  '), isNull);
    expect(AuthValidators.email(''), AuthFieldError.emailInvalid);
    expect(AuthValidators.email(null), AuthFieldError.emailInvalid);
    expect(AuthValidators.email('rina'), AuthFieldError.emailInvalid);
    expect(AuthValidators.email('rina@contoh'), AuthFieldError.emailInvalid);
    expect(AuthValidators.email('a b@c.de'), AuthFieldError.emailInvalid);
  });

  test('kata sandi minimal 8 karakter', () {
    expect(AuthValidators.password('1234567'), AuthFieldError.passwordTooShort);
    expect(AuthValidators.password('12345678'), isNull);
    expect(AuthValidators.password(null), AuthFieldError.passwordTooShort);
  });

  test('nama 1..40 setelah dipangkas', () {
    expect(AuthValidators.displayName(''), AuthFieldError.nameEmpty);
    expect(AuthValidators.displayName('   '), AuthFieldError.nameEmpty);
    expect(AuthValidators.displayName('R'), isNull);
    expect(AuthValidators.displayName('a' * 40), isNull);
    expect(AuthValidators.displayName('a' * 41), AuthFieldError.nameTooLong);
    expect(AuthValidators.displayName('  ${'a' * 40}  '), isNull);
  });
}
