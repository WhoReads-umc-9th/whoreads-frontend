# Google Play / Actions 배포 점검

2026-10-11 KST, 로그인한 Play Console과 실제 다운로드 파일을 확인했다.

- 앱: `com.whoreads.mobile`, 기존 트랙: 비공개 테스트 Alpha.
- 제공 중: `1.0.2`, versionCode `3`, 2026-10-07 21:22 게시, 전체 출시.
- Play에 업로드된 최고 versionCode: `3` (목록에 1, 2, 3).
- 게시 개요의 미제출 변경 2개는 공개 테스트의 대한민국 추가와 프로덕션 동기화 해제이며 현재 Alpha 앱 배포와 별개다. 제출하지 않았다.
- Actions 실행: [37615236003](https://github.com/WhoReads-umc-9th/whoreads-frontend/actions/runs/37615236003), SHA `e35f4048e9ab202982491e51ea97d294201a4155`, app-release artifact `11479890335`.
- Play 원본 `3.aab`와 Actions AAB의 SHA256이 같다: `6e7c57983d3cc9f0f52acbdb19732c6d88067eb7f37850ad8a4bb46b2bb6fc44`.
- 해당 AAB의 dotenv에는 `KAKAO_REST_API_KEY`가 없고 BASE_URL은 과거 HTTP IP 주소다. 현재 REST 로그인 구현은 키 누락 시 인가 페이지 전에 실패한다.
- GitHub Secrets의 BASE_URL을 실제 로그인 검증에 사용한 현재 HTTPS 백엔드로 갱신하고 기존 로컬 설정의 REST 키, native 키, redirect URI를 등록했다. 키 값과 계정 비밀번호는 기록하지 않았다.
- workflow가 Kakao 환경변수를 포함하고, 빌드 전 및 APK/AAB 빌드 후 설정 검사를 수행하도록 수정했다. 잘못된 키/주소가 있으면 artifact 업로드를 차단한다.
- 재업로드 준비 버전: `1.0.3+4`. 현재 점검에서는 새 파일을 Play에 업로드하거나 검토 제출하지 않았다.
- `scripts/prepare_play_release.py`는 최신 main 성공 빌드만 다운로드하고 설정/버전 검사를 수행한다. 기존 깨진 `1.0.2(3)` 파일을 실제 실행에서 거절했다.
- 유효 설정, 잘못된 키/주소, APK/AAB dotenv 검사, 최신 빌드 선택, 스킬 구조 및 workflow YAML 검사를 통과했다.
- Codex 자동화 `whoreads-aab`는 PAUSED로 생성했다. 예약 게시 없이 사용자의 배포 요청 또는 수동 실행으로 기존 Alpha 트랙 배포를 수행한다.

화면 증거: [Alpha 제공 상태](play-alpha.png), [미제출 공개 테스트 변경](play-publishing.png).

새 Android release 파일의 기기 로그인과 Google Play의 새 배포 검증은 별도다. 이전 iOS 시뮬레이터 로그인 성공을 새 Android 배포 통과로 취급하지 않는다.
