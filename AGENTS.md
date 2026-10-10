# WhoReads release automation

사용자가 이 프로젝트에서 "배포해줘", "Play 배포", "최신 AAB 배포"를 요청하면
[WhoReads Play release skill](.agents/skills/whoreads-play-release/SKILL.md)을 읽고 실행한다.
GitHub Actions의 최신 main 아티팩트를 검증해 기존 Google Play 비공개 테스트 트랙을 갱신한다.
상태 확인 요청에서는 게시하지 않는다. 로그인 비밀번호나 OTP를 저장하지 않는다.
