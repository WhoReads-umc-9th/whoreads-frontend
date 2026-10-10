import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/services/kakao_oauth_session.dart';

void main() {
  const base = 'https://example.invalid/api';
  final redirect = Uri.parse('$base/auth/kakao/callback');
  late KakaoOAuthSession session;

  setUp(() {
    session = KakaoOAuthSession(redirectUri: redirect, state: 'test-session');
  });

  test('앱 키 없이 서버의 로그인 시작 주소와 state를 만든다', () {
    final uri = session.authorizationUri;
    expect(uri.origin, 'https://example.invalid');
    expect(uri.path, '/api/auth/kakao/authorize');
    expect(uri.queryParameters, {'state': 'test-session'});
  });

  test('로그인 시도마다 새 state를 만든다', () {
    final first = KakaoOAuthSession.forBackend(apiBaseUrl: base);
    final second = KakaoOAuthSession.forBackend(apiBaseUrl: base);
    expect(first.state.length, greaterThanOrEqualTo(32));
    expect(first.state, isNot(second.state));
    expect(first.redirectUri, redirect);
  });

  test('정확한 콜백의 code를 디코딩하여 반환한다', () {
    final callback = session.parseCallback(
      redirect.replace(
        queryParameters: {'code': 'test+&=code', 'state': session.state},
      ),
    );
    expect(callback.code, 'test+&=code');
    expect(callback.errorMessage, isNull);
  });

  for (final suffix in [
    '?code=test&state=other',
    '?code=test',
    '?code=test&code=other&state=test-session',
    '?code=test&state=test-session&state=test-session',
    '?state=test-session',
    '?code=&state=test-session',
    '?code=test&error=access_denied&state=test-session',
    '?code=test&state=test-session#fragment',
  ]) {
    test('불완전하거나 변조된 콜백을 거절한다: $suffix', () {
      final callback = session.parseCallback(Uri.parse('$redirect$suffix'));
      expect(callback.code, isNull);
      expect(callback.errorMessage, isNotNull);
    });
  }

  test('유사한 호스트나 경로를 콜백으로 취급하지 않는다', () {
    for (final uri in [
      redirect.replace(host: 'example.invalid.attacker.invalid'),
      redirect.replace(path: '${redirect.path}/extra'),
      redirect.replace(scheme: 'http'),
      redirect.replace(port: 444),
      redirect.replace(userInfo: 'user'),
    ]) {
      expect(session.isCallback(uri), isFalse);
      expect(session.parseCallback(uri).code, isNull);
    }
  });

  test('동의 취소는 오류 메시지 없이 종료한다', () {
    final callback = session.parseCallback(
      redirect.replace(
        queryParameters: {'error': 'access_denied', 'state': session.state},
      ),
    );
    expect(callback.code, isNull);
    expect(callback.errorMessage, isNull);
  });

  test('키 설정 없이 서버 주소만으로 로그인을 시작한다', () {
    final created = KakaoOAuthSession.forBackend(apiBaseUrl: base);
    expect(created.authorizationUri.queryParameters.keys, ['state']);
    expect(created.redirectUri, redirect);
  });

  test('안전하지 않은 서버 주소로 로그인을 시작하지 않는다', () {
    for (final address in [
      'http://example.invalid/api',
      'https://user@example.invalid/api',
      'https://example.invalid/api?injected=1',
      'https://example.invalid/api#fragment',
    ]) {
      expect(
        () => KakaoOAuthSession.forBackend(apiBaseUrl: address),
        throwsFormatException,
      );
    }
  });
}
