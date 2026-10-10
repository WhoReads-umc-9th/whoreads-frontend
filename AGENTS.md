# WhoReads release automation

사용자가 이 프로젝트에서 "배포해줘", "Play 배포", "최신 AAB 배포"를 요청하면
[WhoReads Play release skill](.agents/skills/whoreads-play-release/SKILL.md)을 읽고 실행한다.
GitHub Actions의 최신 main 아티팩트를 검증해 기존 Google Play 비공개 테스트 트랙을 갱신한다.
상태 확인 요청에서는 게시하지 않는다. 로그인 비밀번호나 OTP를 저장하지 않는다.

카카오 REST 키와 Client Secret은 백엔드 저장소의 GitHub Secrets에서 서버 런타임에만 주입한다.
모바일은 `/api/auth/kakao/authorize?state=...`로 시작하며 앱에 카카오 키를 넣지 않는다.
모바일 `.env`에는 BASE_URL만 허용한다. 어드민 키, client secret, 서명 비밀번호,
서비스 계정 비밀 키는 앱에 포함하지 않는다. 빌드 전 `scripts/release_config.py write-env`로
환경변수에서 BASE_URL만 생성하고, audit로 APK/AAB에 추가 변수가 없는지 확인한다.
이 서버 엔드포인트 배포와 HTTPS 302/state/callback 검증이 끝나야 새 모바일 앱을 배포한다.
