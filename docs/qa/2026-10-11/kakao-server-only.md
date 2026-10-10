# 카카오 키 서버 관리 변경

모바일 앱은 BASE_URL만 포함한다. WebView에서 서버 `/api/auth/kakao/authorize?state=...`를
열고 서버가 카카오 인가 화면으로 연결한다. REST 키와 Client Secret은 백엔드 GitHub Secrets에서
EC2 런타임 환경변수로만 주입한다. 기존 token_data/registration_token 분기는 유지한다.

Android Actions에서 카카오 관련 Secrets 주입을 제거했고 iOS 네이티브 키 URL scheme도 제거했다.
release_config의 APK/AAB audit는 BASE_URL 외 변수가 있으면 거절한다. 배포 준비 스크립트는
서버의 302/state/고정 callback/no-store를 검증하여 서버 준비 전 앱 업로드를 막는다.

웹의 기존 JavaScript SDK 흐름은 유지한다. JavaScript 공개 플랫폼 식별자는 별도 웹 설정에서
필요할 수 있으며 모바일 빌드에는 포함하지 않는다. Firebase 클라이언트 공개 설정 및 앱 서명은
기존 용도로 유지한다. 카카오의 client_id는 OAuth URL에서 보이지만 Client Secret은 전달하지 않는다.

이전 Git 이력과 이전 빌드 파일의 플랫폼 키는 이 변경으로 삭제되지 않는다.
실제 새 Play 업로드와 기기 로그인 확인은 각각 별도로 기록한다.

검증 완료: Flutter 전체 테스트 69개, analyze error/warning 0개(기존 info 47개),
iOS simulator debug 빌드, key-free dotenv allowlist 검사. 서버 MockMvc 3개 통과.
