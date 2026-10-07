# 카카오 로그인 연결 상태

2026-10-07 공개 서버 명세(`/v3/api-docs`) 기준.

## 현재 모바일 로그인

로그인 버튼은 `UserApi.loginWithKakaoTalk()` 또는
`UserApi.loginWithKakaoAccount()`로 SDK 토큰을 발급받고,
`POST /api/auth/kakao/login/token`에 `access_token`을 전달한다.
네이티브 앱 키에 해당하는 `kakao{NATIVE_APP_KEY}://oauth`는 SDK의 앱 복귀 주소다.

## 백엔드가 전달한 콜백

`https://api.whoreads.kro.kr/api/auth/kakao/callback`

이 URL은 REST 방식으로 인가 코드를 요청할 때의 `redirect_uri`이며,
카카오 개발자 콘솔에도 같은 주소를 등록해야 한다.
현재 서버는 `GET /api/auth/kakao/callback?code=...` 요청에
`ApiResponseKakaoLoginData` JSON을 반환하도록 명세되어 있다.
신규 회원은 `registration_token`, 기존 회원은 `token_data`를 반환한다.
서버 명세에는 앱 복귀 리다이렉트나 결과 교환 API가 없다.

`KakaoAuthService.loginWithAuthorizationCode()`는 REST 방식으로 발급한
미사용 인가 코드를 이 콜백으로 보내고 결과를 처리할 수 있다.
이미 브라우저가 콜백에 전달한 코드를 이 메서드로 다시 교환하면 안 된다.
기존 SDK와 이 메서드는 동일한 로그인 결과 검증 및 토큰 저장 로직을 사용한다.

## 전환을 위해 남은 사항

로그인 버튼은 아직 REST 방식으로 전환하지 않았다. 필요한 정보는 다음과 같다.

- 인가 코드 요청에 사용할 카카오 REST API 키. 네이티브 앱 키로 대체할 수 없다.
- 서버 콜백 처리 후 모바일 앱에 로그인 결과를 전달할 방식.
  시스템 브라우저를 사용할 경우 앱 복귀 주소와 일회용 결과 교환 API 등
  백엔드와 앱 양쪽이 합의한 계약이 필요하다.

현재 SDK의 복귀 스킴을 HTTPS 콜백으로 교체하는 것만으로는 이 계약이 구현되지 않는다.

참고: [카카오 Flutter 로그인](https://developers.kakao.com/docs/ko/kakaologin/flutter),
[카카오 REST 로그인](https://developers.kakao.com/docs/ko/kakaologin/rest-api).
