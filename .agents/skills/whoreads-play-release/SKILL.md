---
name: whoreads-play-release
description: WhoReads Android 앱의 GitHub Actions AAB를 확인하거나 사용자가 배포해줘라고 요청했을 때 Google Play의 기존 테스트 트랙에 배포한다.
---

현재 저장소는 WhoReads-umc-9th/whoreads-frontend, Play 패키지는 com.whoreads.mobile이다.
실행 위치는 /Volumes/AI-Workspace/Mac-mini/Users/haram/coding/flutter/whoreads이다.

사용자의 현재 배포 요청 또는 배포 자동화의 수동 실행을 배포 승인으로 취급한다.
상태 확인 요청에서는 읽기와 파일 준비까지만 진행한다. 정기 예약 배포로 바꾸지 않는다.
계정 비밀번호, 로그인 토큰, OTP를 파일이나 스킬에 저장하지 않는다. 기존 로그인 세션을 사용한다.

1. git 상태와 origin/main을 확인한다. 아직 푸시되지 않은 수정이 있으면 요청된 변경만 검증하고 커밋/푸시해 빌드를 기다린다. 실제 변경을 포함한 SHA를 확인한다. Play의 최신 업로드 버전보다 높도록 표시 버전과 build 번호를 함께 올린다. 서명 키를 교체하지 않는다.
2. 연결된 Play 전용 도구를 먼저 확인하고, 없으면 설치된 chrome:control-chrome 스킬의 browser-client를 사용한다. 사용자에게 승인받은 플러그인 복구가 필요하면 설치된 같은 버전의 누락 경로만 복구하고 REPL을 재시작한다. 보안 차단을 우회하지 않는다.
3. Play에서 앱/트랙/제공 상태, 보류 중 변경, 초안을 포함한 최고 versionCode를 확인한다. 2026-10-11 확인한 개발자 ID는 6323748251621633962, 앱 ID는 4972264526619622212, 기존 트랙 URL은 https://play.google.com/console/u/1/developers/6323748251621633962/app/4972264526619622212/tracks/4698670068892095329 이다. URL은 현재 계정의 화면에서 확인한다. 프로덕션으로 승격하지 않고 기존 비공개 테스트 트랙을 갱신한다. 다른 트랙 요청이 있으면 그 요청을 따른다.
4. 아래 준비 스크립트를 실행한다. --minimum-version-code에는 Play에서 확인한 최고값을 사용한다. --aapt2에는 현재 설치된 Android SDK build-tools의 실행 파일을 사용한다.

   python3 scripts/prepare_play_release.py --minimum-version-code <최고값> --aapt2 <절대경로>

   스크립트는 가장 최신 main 빌드가 성공했는지, 현재 main SHA와 같은지, artifact가 만료되지 않았는지, APK/AAB의 서버 주소가 같은지, APK 패키지/버전이 맞는지 검사하고 AAB 경로와 SHA256을 기록한다. 앱 .env에는 BASE_URL만 허용한다. 카카오 키/비밀 값이 포함된 파일은 거절한다. 서버 `/api/auth/kakao/authorize`의 302/state/callback도 검증한다. 이전 성공 빌드로 조용히 대체하지 않는다. AAB 자체 패키지/버전 및 업로드 서명은 Play 업로드 검증에서 확인한다.
5. 사용자의 배포 요청이 있을 때만 준비된 AAB를 기존 비공개 테스트 트랙에 업로드하고 버전/패키지/서명 확인 및 출시 노트를 검토한 뒤 해당 테스트 업데이트를 제출한다. 기존의 무관한 보류 변경을 함께 제출하지 않는다. Google의 검토 대기/제공 상태를 정확히 구분한다. 중복 업로드가 의심되면 화면에서 먼저 확인한다.
6. 제출 후 버전, 트랙, 검토/제공 상태와 화면 증거를 보고한다. 로그인은 기기에서 새 배포 파일로 확인한 경우에만 실제 통과로 표현한다. 2단계 인증은 사용자 확인이 필요하면 인증 요청을 남기고 준비 작업은 계속한다.
