# 원격 병합 및 iOS 시뮬레이터 확인

2026-10-07, Flutter 3.38.5 / Dart 3.10.4 / Xcode 26.0.

## Git 및 코드

- 진행 중이던 `origin/main` (`b8cc2d7`) 병합의 충돌 2곳을 해결했다.
  기존 서재 추가/책 ID/팔로우 수정과 원격 유명인 이미지 출처 표시를 유지했다.
- 병합 커밋: `f1f65f0`. 이후 `git pull --no-rebase`는 `Already up to date`였다.
- 카카오 서비스 수정은 임시 백업 후 병합 완료 뒤 복원했다.
  콜백 처리 및 테스트/연결 문서는 별도 커밋 `629f499`에 반영했다.
- 기존 미추적 `assets/images/profile_avatars/`는 수정하거나 커밋하지 않았다.

## 검증

- `flutter test --no-pub --reporter expanded`: 40개 모두 통과.
- `flutter analyze --no-pub`: 오류 0, 경고 0, info 46.
  info는 기존 스타일/사용 중단 API 안내이며 분석 명령은 이 때문에 종료 코드 1을 반환했다.
- `flutter build ios --simulator --debug --no-pub`: 성공, Xcode 빌드 73.1초.
- `flutter run --no-pub --debug -d 918C753C-C25E-4D67-981C-51DE0881950E`:
  iOS 26.0의 iPhone 16e에서 성공, Xcode 빌드 49.0초.
  Dart VM Service 연결 및 `/api/health`의 UP 응답을 확인했다.
- `otool -L build/ios/iphonesimulator/Runner.app/Runner.debug.dylib`:
  시뮬레이터 arm64/x86_64 모두 `@rpath/Flutter.framework/Flutter` 링크를 확인했다.

## 링커 오류와 남은 설정

사용자가 보고한 `_FlutterMethodNotImplemented`, `_OBJC_CLASS_$_FlutterAppDelegate`
등 Undefined symbol 오류는 위 빌드/실행에서 재현되지 않았다.
빌드 산출물을 다시 생성한 현재 상태에서는 Flutter가 정상 연결된다.
명시적 `OTHER_LDFLAGS`에 Flutter가 없다는 사실만으로 원인을 단정할 수 없으며,
불필요한 Xcode 링크 설정 변경은 하지 않았다. 이전 캐시/산출물 문제는 추정이다.

실행 로그에는 다음 별도 항목이 남았다.

- iOS에 `GoogleService-Info.plist` 또는 iOS Firebase 옵션이 없다.
  `Firebase.initializeApp()` 실패를 기존 코드가 처리해 앱 실행은 계속되지만,
  iOS 푸시 초기화는 검증되지 않았다. 유효한 iOS Firebase 앱 설정이 필요하다.
- `Target native_assets required define SdkRoot but it was not provided` 안내가 출력됐다.
  현재 시뮬레이터 빌드, 설치, 실행 및 Dart VM 연결은 성공했다.
- 최초 검증 당시에는 카카오 서버 콜백 메서드만 추가되어 모바일 버튼은 SDK 흐름이었다.
  이후 REST 키를 전달받아 모바일 버튼 연결까지 완료했다. 아래 추가 검증과
  [현재 연결 문서](../../kakao-login.md)를 참고한다.

Firebase 계정 설정, 실제 카카오 로그인, 배포/원격 push는 수행하지 않았다.


## REST 키 제공 후 모바일 카카오 연결 검증

- Android/iOS 버튼을 REST 인가 → WebView 콜백 차단 → 서버 GET 콜백 흐름으로 연결했다.
- `flutter test --no-pub`: **59개 전체 통과**. Android/iOS 로그인 진입, 정상 코드 교환,
  기존 회원 토큰 저장, 신규 회원 가입 정보 반환, 취소와 잘못된 state 거절을 확인했다.
  서버 응답과 인증 콜백은 테스트에서 모의 처리했다.
- `flutter analyze --no-pub --no-fatal-infos`: 오류/경고 없이 종료. 기존 정보 수준 진단 46개.
- `flutter build ios --simulator --debug --no-pub`: 성공. WebView CocoaPods 설치 및 링크 완료.
- 전달받은 로컬 REST 키/URI로 카카오 인가 엔드포인트를 읽기 요청한 결과
  HTTP 200으로 accounts.kakao.com 로그인 화면 주소까지 이동했다.
- iPhone 16e 시뮬레이터에서 업데이트된 앱을 실행하고, 온보딩 로그인 버튼과
  바텀시트의 카카오 로그인 버튼 콜백을 VM Service로 실행했다.
  실제 카카오계정 아이디/비밀번호 입력 화면 렌더링을 확인했다.
  [확인 화면](kakao-rest-login.png). 계정 정보 입력이나 인증 제출은 하지 않았다.
- Android 배포용 manifest에 INTERNET 권한을 추가했다. Android 네이티브 빌드는 미검증.
- 실제 카카오 계정 인증, 운영 서버의 코드 교환과 회원가입 완료는 미검증.
  카카오 콘솔의 Redirect URI와 백엔드의 키/URI 설정도 같은 값이어야 한다.
