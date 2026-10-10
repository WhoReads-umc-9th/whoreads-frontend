# WhoReads release automation

사용자가 이 프로젝트에서 "배포해줘", "Play 배포", "최신 AAB 배포"를 요청하면
[WhoReads Play release skill](.agents/skills/whoreads-play-release/SKILL.md)을 읽고 실행한다.
GitHub Actions의 최신 main 아티팩트를 검증해 기존 Google Play 비공개 테스트 트랙을 갱신한다.
상태 확인 요청에서는 게시하지 않는다. 로그인 비밀번호나 OTP를 저장하지 않는다.

키 값은 GitHub Actions Secrets에서 빌드 시 주입한다. 실제 키를 추적 파일에 넣지 않는다.
앱에 필요한 플랫폼 키만 dotenv에 허용하며 서버 어드민 키, client secret, 서명 비밀번호,
서비스 계정 비밀 키는 앱에 포함하지 않는다. iOS 빌드 전에는 `scripts/release_config.py write-env`로
로컬 환경변수 또는 CI Secrets에서 `.env`와 무시되는 `ios/Flutter/Kakao.xcconfig`를 생성한다.
