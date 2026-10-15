# Google Play 비공개 테스트 자동 배포

`main` push 또는 Actions의 **Flutter Android Release and Play Closed Test → Run workflow**로 실행한다.
정기 예약 실행은 없다. 배포 대상은 기존 `com.whoreads.mobile`의 Alpha(`alpha`) 비공개 테스트다.

## 최초 연결

1. Google Cloud 프로젝트에서 **Google Play Android Developer API**를 활성화한다.
2. Play 배포 전용 서비스 계정을 만든다. Firebase Admin 계정을 재사용하거나 Cloud 관리자 역할을 부여하지 않는다.
3. Play Console → 사용자 및 권한에서 이 서비스 계정에 **WhoReads 앱만** 읽기 및 테스트 트랙 출시 권한을 부여한다. 프로덕션 출시, 재무, 사용자 관리 권한은 부여하지 않는다.
4. 서비스 계정 JSON을 저장소 Actions Secret `PLAY_SERVICE_ACCOUNT_JSON`에 등록한다. 저장소 파일, 모바일 `.env`, 앱, 아티팩트에 키를 넣지 않는다. 생성한 로컬 사본은 등록 후 삭제한다.
5. Play 게시 개요의 무관한 보류 변경은 **나중을 위해 저장**으로 분리한 뒤, Actions Variable `PLAY_AUTO_DEPLOY`를 `true`로 설정한다.

기존 `BASE_URL`, `GOOGLE_SERVICES_JSON` 및 Android 업로드 서명 Secrets도 필요하다.
`PLAY_AUTO_DEPLOY`가 비어 있거나 `false`이면 빌드만 수행하고 제출은 건너뛴다고 요약에 표시한다.
활성화된 상태에서 인증 또는 검증이 실패하면 배포가 실패하며, 이전 성공 AAB로 대체하지 않는다.

## 실행 과정

- Play의 모든 현재 AAB/APK와 트랙 초안까지 조회해 최고 versionCode보다 큰 번호를 할당한다. pubspec에 더 높은 버전이 명시되면 우선 사용한다. 자동 증가 시 표시 버전의 patch도 함께 증가한다. 실제 버전은 `release-plan`과 `release-manifest.json`에 기록하며 pubspec을 자동 커밋하지 않는다.
- HTTPS Kakao authorize의 302, state, callback 및 no-store 검증과 Flutter 테스트가 통과해야 서명 빌드를 만든다.
- 빌드에는 BASE_URL만 포함하며 APK/AAB 설정을 검사한다. 배포용 서비스 계정은 prepare/publish 작업에서만 사용하고 Flutter build 작업에는 전달하지 않는다.
- 같은 실행에서 생성한 AAB/APK의 SHA256, APK 패키지/버전 및 커밋을 기록하고 제출 전에 다시 확인한다. Play가 반환한 AAB versionCode/SHA256도 비교한다.
- 동시 실행을 직렬화하고, 제출 시 main에 새 커밋이 있으면 이전 빌드를 차단한다. Alpha만 수정하며 다른 트랙은 같은 API edit 안에서 변경되지 않았는지 확인한다.
- 이미 같은 커밋/버전이 Alpha에 기록됐으면 업로드하지 않는다. 업로드·제출이 애매하게 실패하면 자동 재시도하지 않는다. Play Console의 실제 상태부터 확인한다.
- `ERROR_IF_IN_REVIEW`로 기존 심사를 취소하지 않는다. 거절 시 미제출 상태로 조용히 바꾸는 fallback도 없다.

Play API 제출 성공은 **Google 심사 승인 또는 테스터 제공 완료**를 의미하지 않는다.
`play-submission-result`와 Play Console에서 상태를 확인한다. 향후 Console에서 별도의 보류 변경을 만들 때도 자동 배포와 함께 제출되지 않도록 나중을 위해 저장한다.

## 중지 및 문제 확인

Actions Variable `PLAY_AUTO_DEPLOY=false`로 다음 실행부터 업로드를 중지한다. 진행 중 제출은 취소하지 않는다.
인증 오류는 서비스 계정의 앱 접근 권한과 API 활성화를 확인하고, versionCode 중복은 Play의 초안·업로드 상태를 먼저 확인한다.
심사 중이라 제출이 막히면 심사 완료 후 최신 main의 워크플로를 실행한다.

## 로컬 검증

```sh
bundle install
bundle exec ruby fastlane/play_release_test.rb
BASE_URL=https://api.whoreads.kro.kr python3 scripts/release_config.py write-env
python3 scripts/release_config.py verify-server .env
```

공식 문서: [Play API 연결](https://developers.google.com/android-publisher/getting_started),
[fastlane](https://docs.fastlane.tools/actions/upload_to_play_store/),
[심사 중 commit 정책](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit).
