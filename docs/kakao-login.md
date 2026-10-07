# 카카오 로그인 연결 상태

2026-10-07 공개 서버 명세(`/v3/api-docs`) 기준.

## 모바일 로그인 버튼

Android/iOS 로그인 버튼은 REST API 키로 카카오계정 로그인 화면을 앱 안의
WebView에 연다. 카카오톡 앱 SSO 대신 카카오계정 인증을 사용한다.

1. `https://kauth.kakao.com/oauth/authorize`에 REST 키, `response_type=code`,
   서버 `redirect_uri`, 로그인 시도마다 새로 생성한 `state`를 전달한다.
2. WebView가 정확한 서버 콜백 주소로 이동할 때 탐색을 차단한다.
   `state`를 검증하고 인가 코드를 로그인 서비스에 반환한다.
3. 서비스가 `GET /api/auth/kakao/callback?code=...`를 한 번 호출한다.
   브라우저가 먼저 코드를 교환하지 않으므로 코드 중복 사용을 방지한다.
4. 기존 회원은 `token_data`를 저장하고 홈으로 이동한다.
   신규 회원은 `registration_token`으로 닉네임/성별/연령 입력 화면에 진입하고,
   `POST /api/auth/kakao/signup` 완료 후 홈으로 이동한다.

서버 콜백은 JSON을 반환한다. 이 흐름에서는 별도 앱 복귀 리다이렉트나
서버 수정 없이 앱이 결과를 처리한다. 웹 플랫폼의 기존 SDK 흐름은 유지한다.

## 환경 설정

실제 키는 Git에서 제외된 `.env`에 설정한다. `.env.example`에는 키를 넣지 않는다.

```dotenv
BASE_URL=https://api.whoreads.kro.kr
KAKAO_REST_API_KEY=<카카오 REST API 키>
KAKAO_REDIRECT_URI=https://api.whoreads.kro.kr/api/auth/kakao/callback
```

카카오 개발자 콘솔에도 같은 Redirect URI를 등록해야 한다.
앱의 인가 요청 주소와 백엔드의 코드 교환 주소는 정확히 같아야 한다.
네이티브 앱 키는 REST API 키 대신 사용할 수 없다.
`.env` 변경 후에는 앱을 완전히 다시 실행해야 반영된다.

## 실패 및 취소 처리

로그인 창을 닫거나 동의를 취소하면 서버를 호출하지 않는다.
잘못된 `state`, 중복 인가 코드 파라미터, 다른 콜백 주소는 거절한다.
인가 코드는 자동 재시도하지 않으며 코드/토큰/계정 비밀번호를 로그에 남기지 않는다.
로그인 버튼을 연속 누르더라도 한 번의 로그인만 시작한다.

참고: [카카오 REST 로그인](https://developers.kakao.com/docs/ko/kakaologin/rest-api),
[Flutter WebView](https://pub.dev/packages/webview_flutter).
