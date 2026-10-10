# 빌드 키 관리 점검

- 실제 Kakao 플랫폼 키는 GitHub Actions Secrets로 관리한다. tracked dotenv, 키스토어, key.properties는 없다.
- 기존 iOS Info.plist의 네이티브 키 리터럴을 빌드 변수로 교체했다. 로컬/CI 환경변수에서 `scripts/release_config.py write-env`가 무시되는 `ios/Flutter/Kakao.xcconfig`를 생성한다. Debug/Release/Profile 설정에 적용된다. 기존 키의 Git 과거 기록은 이 변경으로 삭제되지 않는다.
- GitHub Secrets는 저장소 소스 노출을 막지만 APK/AAB에 필요한 플랫폼 키를 추출 불가능하게 만드는 기능은 아니다. 로그인 식별용 플랫폼 키와 서버 비밀 키를 구분한다.
- 앱 dotenv는 허용된 BASE_URL, Kakao 플랫폼 키, redirect URI만 포함한다. 어드민 키, client secret, DB 비밀번호, signing 비밀번호와 서비스 계정 비밀 키를 앱에 포함하지 않는다. 알 수 없는 dotenv 변수가 포함된 APK/AAB는 거절한다.
- Firebase 설정은 모바일 앱 설정 형태만 허용하고 서비스 계정 JSON을 거절한다. 서명 입력은 Secrets를 환경변수로 전달해 Python이 생성하므로 쉘 구문으로 해석되지 않는다.
- 생성 파일은 소유자만 읽고 쓸 수 있는 권한(0600)으로 쓰고 CI 종료 시 삭제한다. 아티팩트 업로드 경로는 APK/AAB 두 파일로 한정한다.
- `.env` 파생 파일, 키스토어, 서명 설정 및 서비스 계정 파일을 Git에서 제외한다. CI는 추적 소스에 현재 플랫폼 키 리터럴이 있으면 실패한다.
- 보안 설정 변경 때문에 실제 키를 재발급하거나 서명 키를 교체하지 않았다. 서버의 client secret 활성화, 호출 IP/플랫폼 제한 설정은 이 프론트 저장소 점검으로 검증되지 않는다.

근거: [카카오 보안 권장 사항](https://developers.kakao.com/docs/ko/getting-started/security-guideline), [GitHub Actions Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).
