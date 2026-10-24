# WhoReads iOS 최초 서명 및 TestFlight 검증 — 2026-10-21

## 완료된 최초 서명

- 대상: `com.example.whoreads`, Apple 팀 `H78DY23Q9M`.
- [최초 서명 자료 생성 실행](https://github.com/WhoReads-umc-9th/whoreads-frontend/actions/runs/39597838722): 성공.
- Apple Distribution 인증서를 이 Mac의 CSR 개인 키와 대조하고 WhoReads App Store 프로파일 범위 및 인증서를 검증했다.
- 프로파일: `WhoReads GitHub TestFlight`, 만료일 `2027-10-21`.
- 이 Mac에서 실제 기존 앱 아카이브를 내부 TestFlight용 IPA로 내보내고 `codesign --verify --deep --strict` 검증에 통과했다.
- 로컬 서명 검증에서는 기존 아카이브를 재업로드하지 않았다. 임시 keychain과 설치한 프로파일을 정리하고 이전 keychain 목록을 복원했다.
- GitHub에 `IOS_DISTRIBUTION_CERTIFICATE_BASE64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`를 등록했다. 비밀 값은 이 문서에 기록하지 않는다.
- GitHub의 `IOS_SETUP_KEY_ID`, `IOS_SETUP_PRIVATE_KEY`는 최초 설정 후 삭제했다.
- Apple의 임시 관리자 API 키 해지는 사용자 요청에 따라 나중에 진행한다. 기존 Developer 키는 계속 사용한다.

## 실제 자동 배포 검증

- [첫 TestFlight CI 실행](https://github.com/WhoReads-umc-9th/whoreads-frontend/actions/runs/39597992646).
- 소스 커밋: `5d91c762d75dc8e6adf622ba405f0185aa374b59`.
- 계획된 버전: `1.0.4 (5)`.
- prepare, build, publish, notify 작업 모두 성공했다.
- Xcode 26.3에서 IPA 내보내기 및 BASE_URL 전용 앱 설정 검증을 통과했다.
- Apple 처리 결과: `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`.
- 기존 `WhoReads Internal` 그룹에서 이 빌드가 연결된 것을 별도 API 조회로 확인했다. 그룹 반영은 업로드 직후보다 늦게 완료됐으며, 추가 그룹·테스터 변경 없이 자동으로 반영됐다.
- Apple 빌드 ID: `5abfcfb6-3660-4d1c-aaff-d0b46f6a0438`, 검증 시각: `2026-10-21T12:29:10Z`.
- IPA SHA256: `0cf9dee2cc333d2a1ca81abc95f6447cb87e29612c1114faac3b63c4f80cdb82`.
- Discord가 `[WhoReads] - ios TestFlight 완료` 메시지 전송을 확인했다. 메시지 ID: `1562442709757726802`.
- main push 시 동일한 워크플로가 실행된다. 최초 검증은 iOS 워크플로 수동 실행으로 완료했으며 Android 중복 배포를 만들지 않았다.
- App Store 공개 심사·출시는 진행하지 않았다.
- 실제 iPhone 설치·로그인·푸시 알림 검증은 이번 자동 배포 검증에 포함하지 않았다.
- Apple 업로드 응답에는 2027년 4월부터 iOS 최소 지원 버전을 15.0 이상으로 변경해야 한다는 비차단 경고가 있었다. 현재 빌드는 정상 처리됐다.

## 정리

- 생성·복호화 과정의 Mac 임시 개인 키, .p12 및 비밀번호, .p8 복사본과 프로파일 파일을 삭제했다. 일반 배포용 비밀 값은 승인된 GitHub Actions Secrets에만 유지한다.
- Apple의 임시 관리자 키 자체 해지는 사용자가 나중에 처리하기로 했다. GitHub에 해당 키 값은 남아 있지 않다.
