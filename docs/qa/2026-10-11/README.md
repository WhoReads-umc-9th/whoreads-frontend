# 2026-10-11 업데이트 점검

## 가로모드

- 844×390 논리 픽셀, 하단 안전 영역 21px의 위젯 테스트에서 DNA 결과 화면은
  하단 11px, 회원가입 약관 화면은 31px 넘침을 재현했다. 로그인 방식 화면은 통과했다.
- 요청한 대안에 따라 모바일 시작 시 `portraitUp`을 지정하고 Android MainActivity와
  iOS/iPad 지원 방향도 세로로 제한했다. iPad에는 전체 화면 요구 설정을 추가했다.
- 390×844, 상단 47px/하단 34px 안전 영역에서 같은 세 화면의 레이아웃 테스트는 통과했다.
- Android 16/API 36 이상의 큰 화면(600dp 이상)에서는 운영체제가 방향 제한을
  무시할 수 있다. 큰 화면의 가로 대응과 실제 Android/iPad 회전은 별도 검증이 필요하다.
  참고: [Flutter 방향 제한](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html),
  [Android 큰 화면 정책](https://developer.android.com/develop/ui/compose/layouts/adaptive/app-orientation-aspect-ratio-resizability).

## 가입 후 DNA 추천도서 진입

- 버튼 자체는 이미 `CelebritiesBookPage(celebrityId: result.celebrityId)`로 이동한다.
  보호된 API가 401을 반환하고 세션 갱신에 실패하면 공통 인터셉터가 로그인 화면으로 이동한다.
- 현재 운영 서버 `/v3/api-docs`의 이메일 가입 응답 `JoinData`에는 access token만 있고
  refresh token이 없다. 앱은 시작할 때 무조건 refresh를 시도하여 이 세션을 지울 수 있었고,
  access token이 만료된 뒤 추천도서 API를 요청하면 세션을 갱신할 방법도 없었다.
- 이메일 가입 성공 후 갱신 토큰이 없다면 같은 가입 정보로 로그인하여 정상 세션을 저장한다.
  자동 로그인이 실패하면 가입 완료 안내와 로그인 화면을 보여줘 중복 가입을 막는다.
- 앱 시작은 현재 access token으로 `/members/me`를 먼저 검증하고, 실제 401이 있을 때만
  기존 갱신 흐름을 사용한다. 새 세션에 refresh token이 없으면 이전 계정의 토큰도 제거한다.
- 실제 네트워크 인터셉터와 로컬 HTTP 서버를 사용한 테스트에서 access-only 세션 유지,
  이전 refresh token 제거, 만료 세션 종료, 서버 장애 시 세션 보존을 검증했다.
- 모의 API를 사용한 화면 연결 테스트에서 가입 → 로그인 토큰 저장 → DNA 5문항 → 결과 →
  추천도서 버튼 → 같은 유명인 상세 화면을 확인했다. 추천도서 API에도 로그인 토큰이 전달됐다.
  자동 로그인 실패 시 가입을 다시 요청하지 않고 로그인 화면으로 이동하는 테스트도 통과했다.
- 임시 QA 정보의 직접 가입 요청은 HTTP 401로 거절되어 계정은 생성되지 않았다.
  이메일 검증부터 진행하는 실제 신규 가입 전체 흐름과 보고된 장애의 동일 조건 재현은 미검증이다.
  확인된 세션 결함과 회귀 테스트를 근거로 수정했으며, 원인의 단독 확정은 아니다.

## 카카오 로그인

- iPhone 16e / iOS 26 시뮬레이터의 실제 WebView에서 전달받은 계정으로 로그인했다.
- 카카오톡 2단계 확인은 사용자가 승인했다. 계정 확인 화면에서 계속하기를 눌러
  서버 콜백 처리 후 기존 회원 홈 진입을 확인했다. 모의 서버/콜백을 사용하지 않았다.
- 로그인 후 실제 유명인 상세 화면에서 리처드 브랜슨의 추천도서 53개를 불러왔다.
  팔로우/서재 추가 등의 데이터 변경은 하지 않았다. DNA 답변/결과도 운영 계정에 제출하지 않았다.
- 계정 비밀번호·인가 코드·토큰을 소스, 테스트, QA 문서에 기록하지 않았다.
  신규 카카오 가입과 Android 실제 기기 로그인은 별도 검증 범위다.

## 검증 결과

- `flutter test --no-pub --reporter expanded`: 69개 전체 통과.
- `flutter analyze --no-pub --no-fatal-infos`: 오류/경고 0, 기존 정보 수준 진단 47개.
- iOS/Android 빌드 결과는 아래에 추가 기록한다.
- 기존 미추적 `assets/images/profile_avatars/`는 변경하거나 포함하지 않았다.

### iOS 빌드 및 재실행

- 수정 후 `flutter run --no-pub --debug -d 918C753C-C25E-4D67-981C-51DE0881950E`:
  Xcode 빌드 21.3초, 설치/실행과 Dart VM Service 연결 성공.
- 빌드된 `Runner.app/Info.plist`의 iPhone/iPad 방향 배열 모두
  `UIInterfaceOrientationPortrait` 하나만 포함하고 `UIRequiresFullScreen=true`이다.
- 재실행 후에도 카카오 로그인 세션과 홈 데이터가 유지됐다.
  [홈 화면](kakao-home.png), [운영 서버 추천도서 화면](kakao-recommendations.png).
- 시뮬레이터 UI를 통한 실제 회전 조작은 확인하지 못했다. 네이티브 빌드 설정과
  세로 화면 표시까지만 검증했다. 기존 iOS Firebase 초기화 실패 로그는 별도 설정 문제로 남는다.

### Android 빌드

- `flutter build apk --debug --no-pub --target-platform android-arm64`: 성공, Gradle 66.5초.
- 결과: `build/app/outputs/flutter-apk/app-debug.apk`.
- 연결된 Android 기기가 없어 Android 로그인과 실제 회전은 실행 검증하지 않았다.

### 커밋

- `e4c9cd4`: 모바일 앱 세로모드 제한 및 세로 레이아웃 검증.
- `69169d7`: 가입 후 갱신 가능한 세션 유지 및 가입/추천도서 연결 회귀 테스트.
- 로컬 커밋이며 원격 push와 스토어 업로드는 수행하지 않았다.
