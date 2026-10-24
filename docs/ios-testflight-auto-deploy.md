# iOS TestFlight 자동 배포

`main` push 또는 **WhoReads iOS TestFlight → Run workflow**로 GitHub Actions에서 실행한다.
로컬 Mac이 켜져 있을 필요는 없다. 정기 예약 실행과 App Store 정식 출시 단계는 없다.

## 실행과 알림

1. 기존 WhoReads 앱과 내부 그룹을 읽기 전용 API로 확인하고 다음 버전을 정한다.
2. macOS runner에서 테스트와 Kakao 서버 검증 후 서명 IPA를 만든다.
3. 앱 식별자·버전·dotenv·SHA256을 검사하고 최신 main인지 다시 확인한다.
4. Apple에 업로드하고 정확히 그 빌드가 처리되어 기존 내부 그룹에서 사용 가능한지 기다린다.
5. Discord에 `[WhoReads] - ios TestFlight 완료`와 버전, Actions 실행 링크를 보낸다.

빌드나 업로드가 실패하거나 Apple 처리 시간이 초과되면 `실패 또는 확인 필요`로 알린다.
업로드 접수만으로 완료 메시지를 보내지 않는다. Discord는 `wait=true` 응답의 메시지 ID로 전송을 확인한다.
같은 실행의 알림은 전송 전에 Actions artifact로 기록하여 애매한 전송 실패를 자동으로 반복하지 않는다.
재실행으로 실패에서 성공으로 바뀌면 성공 알림을 별도로 보낼 수 있다.

## 배포 범위

- 앱 `6820093454`, Bundle ID `com.example.whoreads`, 팀 `H78DY23Q9M`
- 기존 그룹 `WhoReads Internal`만 사용하며, 이 그룹의 자동 빌드 접근 설정과 테스터 존재를 확인한다.
- 내보내기에 `testFlightInternalTestingOnly=true`를 고정한다. 이 파일은 외부 TestFlight나 App Store 공개 배포에 사용할 수 없다.
- API 키는 `Developer` 역할을 사용한다. Apple 정책상 팀 키의 앱 범위를 한 앱으로 제한할 수는 없으나, 이 역할에는 정식 출시 심사 제출 권한이 없다.
- 자동화의 Apple REST 호출은 GET만 구현한다. 공개 심사, 국가 설정, 테스터 변경, 기존 빌드 무효화 작업은 구현하지 않는다.
- 향후 공개 배포를 연결할 때에는 별도 승인과 설정 변경, 새 빌드가 필요하다.

## GitHub Actions Secrets

저장소 `WhoReads-umc-9th/whoreads-frontend`에 등록한다. 비밀번호, OTP, Apple 로그인 세션은 CI에 사용하지 않는다.

| Secret | 용도 |
|---|---|
| `ASC_KEY_ID` | Developer 역할 팀 API 키 ID |
| `ASC_ISSUER_ID` | API issuer ID |
| `ASC_PRIVATE_KEY_BASE64` | 한 번 다운로드한 `.p8`의 Base64 |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | CI용 Apple Distribution `.p12`의 Base64 |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | CI용 `.p12`에 생성한 임의 비밀번호 |
| `IOS_PROVISIONING_PROFILE_BASE64` | WhoReads App Store Connect 배포 프로파일의 Base64 |
| `IOS_DISCORD_WEBHOOK_URL` | iOS 결과 알림용 Discord 웹훅 |
| `BASE_URL` | 기존 HTTPS API 서버 주소 |

CI용 배포 인증서와 프로파일은 기존 개발 인증서를 해지하지 않고 별도로 만든다.
빌드할 때마다 인증서나 API 키를 새로 만들지 않는다. 서명 키는 임시 keychain에 설치하고 항상 정리한다.
프로파일 만료 또는 인증서 갱신 시 해당 Secret을 교체한다. 앱 `.env`에는 BASE_URL만 포함한다.
업로드 API 키는 prepare/publish 작업에만, 서명 자료는 build 작업에만, 웹훅은 notify 작업에만 전달한다.

### 다른 노트북에서 최초 서명 설정을 돕는 경우

Apple Developer에 로그인한 Mac을 사용할 수 없다면 App Store Connect에서 임시 관리자 팀 API 키를 만들고,
같은 GitHub 저장소의 `IOS_SETUP_KEY_ID`와 `IOS_SETUP_PRIVATE_KEY`에 각각 키 ID와 `.p8` PEM 전체를 등록한다.
기존 `ASC_*` Developer 키는 교체하지 않는다. 임시 관리자 키는 모든 앱에 대한 권한을 가지므로 최초 설정 후 해지한다.

`Initialize WhoReads iOS Signing`은 수동 main 실행만 허용한다. release Mac에서 생성한 CSR을 입력받아
그 공개 키에 연결된 배포 인증서와 WhoReads App Store 프로파일만 생성하거나 재사용한다.
기존 인증서·프로파일을 삭제하지 않는다. 결과는 CSR 소유자만 복호화할 수 있게 암호화하고 1일 보관한다.
이 작업은 빌드 업로드나 정식 출시를 수행하지 않는다. release Mac에서 결과를 검증한 다음 일반 배포용
`IOS_DISTRIBUTION_CERTIFICATE_*`와 `IOS_PROVISIONING_PROFILE_BASE64`를 등록하고, 두 임시 Setup Secrets를 삭제한다.
Apple의 임시 관리자 API 키도 발급한 사용자가 해지한 뒤 일반 TestFlight 워크플로를 실행한다.

## 버전과 재실행

Apple에 올라간 iOS 버전을 조회해 표시 버전의 patch와 build 번호를 함께 증가시킨다.
pubspec에 더 높은 버전과 번호가 있으면 우선한다. pubspec을 자동 커밋하지 않는다.
선택된 값은 실행별 `ios-release-plan`에 보관하며 재실행 때 같은 값을 사용한다.
다른 업로드의 빌드를 이 실행의 성공으로 간주하지 않는다. 같은 IPA의 업로드 시도가 확인되면 재업로드 대신 상태를 읽는다.
접수 여부가 불분명하면 자동 재전송을 중지하고 Apple 상태를 먼저 대조한다.

아티팩트는 `ios-release-plan`, `ios-testflight-ipa`, `ios-testflight-result`에서 확인한다.
IPA 보관 기간은 14일이다. 테스터의 실제 설치·로그인·기기 알림 검증은 자동화 성공과 구분한다.

## 검증과 중지

```sh
bundle exec ruby fastlane/testflight_release_test.rb
python3 -m unittest discover -s scripts/tests -v
actionlint .github/workflows/ios_testflight.yaml
```

중지하려면 Actions에서 이 iOS 워크플로를 Disable한다. Android 워크플로와 Play 알림 설정은 별도로 유지된다.

공식 문서: [Apple API 키](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/),
[GitHub macOS 서명](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
[Apple 내부 테스트 상태](https://developer.apple.com/documentation/appstoreconnectapi/internalbetastate).
