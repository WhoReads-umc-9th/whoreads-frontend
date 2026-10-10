# 카카오 로그인 연결 상태

2026-10-11 서버 관리 방식으로 변경.

## 모바일 로그인 버튼

Android/iOS 로그인 버튼은 키 없이 서버의 카카오 로그인 진입점을 앱 안의
WebView에 연다. 카카오톡 앱 SSO 대신 카카오계정 인증을 사용한다.

1. `GET /api/auth/kakao/authorize?state=...`를 연다. 로그인 시도마다 새 state를
   생성하며 서버가 REST 키와 고정 redirect_uri로 카카오 인가 URL을 만들어 302로 연결한다.
2. WebView가 정확한 서버 콜백 주소로 이동할 때 탐색을 차단한다.
   `state`를 검증하고 인가 코드를 로그인 서비스에 반환한다.
3. 서비스가 `GET /api/auth/kakao/callback?code=...`를 한 번 호출한다.
   브라우저가 먼저 코드를 교환하지 않으므로 코드 중복 사용을 방지한다.
4. 기존 회원은 `token_data`를 저장하고 홈으로 이동한다.
   신규 회원은 `registration_token`으로 닉네임/성별/연령 입력 화면에 진입하고,
   `POST /api/auth/kakao/signup` 완료 후 홈으로 이동한다.

서버 콜백은 JSON을 반환한다. 이 흐름에서는 별도 앱 복귀 리다이렉트나
서버의 로그인 진입점 배포 후 앱이 결과를 처리한다. 웹 플랫폼의 기존 SDK 흐름은 유지한다.

## 환경 설정

모바일 `.env`에는 서버 주소만 넣는다. 실제 카카오 키는 백엔드 저장소의 GitHub
Secrets에서 서버 런타임 환경변수로만 주입한다. 앱에는 REST/Native 키나 Client Secret을 넣지 않는다.

```dotenv
BASE_URL=https://api.whoreads.kro.kr
```

서버 KAKAO_REDIRECT_URI와 카카오 개발자 콘솔에는 같은 HTTPS 콜백을 등록한다.
모바일은 SDK 초기화나 네이티브 URL scheme 없이 기존 REST 로그인 흐름을 사용한다.
OAuth client_id는 브라우저의 카카오 인가 URL에 보이는 식별자이며 완전히 감출 수 없다.
Client Secret과 어드민 키는 서버에만 보관하고 URL이나 앱 응답에 넣지 않는다.
`.env` 변경 후에는 앱을 완전히 다시 실행해야 반영된다.

## 실패 및 취소 처리

로그인 창을 닫거나 동의를 취소하면 서버를 호출하지 않는다.
잘못된 `state`, 중복 인가 코드 파라미터, 다른 콜백 주소는 거절한다.
인가 코드는 자동 재시도하지 않으며 코드/토큰/계정 비밀번호를 로그에 남기지 않는다.
로그인 버튼을 연속 누르더라도 한 번의 로그인만 시작한다.

참고: [카카오 REST 로그인](https://developers.kakao.com/docs/ko/kakaologin/rest-api),
[Flutter WebView](https://pub.dev/packages/webview_flutter).
