# WhoReads 출시 전 점검 — 2026-09-28

**판정: 출시 보류.** 최신 main 동기화 후 자동 테스트 17개 중 7개 통과, 10개 실패. 실제 서버 로그인·기기 E2E와 서명 AAB 생성은 완료되지 않았다. 실패 테스트는 기대하는 정상 동작을 검사하며, 알려진 결함을 통과 처리하지 않았다.

## 점검 기준과 Git 처리

- 기준: origin/main `3b163d7`을 로컬 main에 병합한 `91682a3`, 로컬 버전·의존성 보존 커밋 `eeeddc4`.
- 로컬의 `1.0.1+2`를 유지했다. 원격의 `1.0.0+2`와 충돌한 버전 한 줄만 기존 로컬 값으로 정리했다.
- 변경 파일 16개를 병합 전후 SHA-256 비교하여 전부 보존했다. 백업은 `.git/codex-backups/20260928-184238`, 백업 브랜치는 `codex/backup-before-release-sync-20260928-184238`, 보존 stash는 `d7769b484858881f6be04166d841f48f5731f221`이다.
- `origin/feat/celebrity-image-copyright`의 `4585d29`, `9a142d9`는 main에 없는 별도 기능 커밋이다. 포함 여부 질문에 대한 확인 전이므로 **미병합**이며 이번 실행 테스트의 대상이 아니다.
- 기존 사용자 아바타 이미지 10개는 미추적 상태 그대로 보존했다. 비밀번호·서명 키·환경 파일은 테스트 및 보고서에 복사하지 않았다.
- 실제 앱 로직의 버그 수정은 아직 하지 않았다. 이번 변경은 Git 동기화, 재현 테스트, 기존 빈 테스트 파일 복구, 점검 보고서다.

## 실제 실행한 검증

| 검증 | 결과 | 범위/한계 |
|---|---|---|
| `flutter test --no-pub --reporter expanded` | **7 통과 / 10 실패**, 종료 코드 1 | API·플랫폼 mock, 인증 갱신은 로컬 HTTP 서버로 실제 interceptor 실행 |
| `flutter analyze --no-pub` | **48건: warning 6 / info 42**, 종료 코드 1 | 분석 error 없음. 이것만으로 런타임 정상 보장 불가 |
| `flutter build appbundle --release --no-pub` | **실패** | main 병합 전 실행. 버전 외 앱 코드는 현재 main과 동일. `:app:validateSigningRelease`에서 `android/key.jks` 없음 |
| 서명 설정 확인 | **막힘** | `android/upload-keystore.jks`는 존재하나 현재 설정의 store password로 열리지 않음. 새 키를 생성하거나 비밀번호를 추측하지 않음 |
| 설정된 API 연결 | **막힘** | HTTP 공개 조회를 8초·15초 제한으로 시도했으나 시간 초과. 같은 IP의 HTTPS는 인증서 IP 불일치 |
| Android API 36 에뮬레이터 | **앱 E2E 미완료** | 기기 연결은 확인. 새 APK 설치·로그인·화면 순회는 완료하지 못함. 실행했던 에뮬레이터 종료 |
| 테스트 계정 로그인 | **미검증** | 사용자 계정 제공 받음. 서버 연결 문제로 실제 자격증명을 전송한 로그인 테스트는 수행하지 않음 |

통과한 테스트: 이메일·카카오 가입 프로필 필수 입력/실패 시 머무름 2개, 정상 로그아웃 토큰 삭제 1개, 실제 빈 서재 응답 1개, 320×568/393×852에서 로그인·가입 프로필·계정 관리 기본 레이아웃 2개, 최초 실행 온보딩 진입 1개. 키보드·접근성 글꼴 확대·실제 카카오 인증 성공까지 검증한 것은 아니다.

실행 로그: [tests.txt](tests.txt), [analyze.txt](analyze.txt).

## 파트별 재현된 실패 10개

P1은 출시 전 우선 수정, P2는 사용자 오류·복구 처리를 보완할 문제다. 테스트 실패 수는 시나리오 수이며, 공통 원인을 공유하는 항목이 있다.

| ID | 파트 / 우선순위 | 재현 조건과 실제 결과 | 원인 위치 / 수정 방향 |
|---|---|---|---|
| A1 | 로그인 갱신 / P1 | API 401 → 갱신 200 → 재요청 200까지 서버가 응답했는데 최초 Future가 3초 후 timeout. 새 토큰 저장도 확인 | `lib/core/network/api_client.dart:24,44` — Queued interceptor 응답 처리 중 동일 큐로 재진입. 갱신·재시도 큐 분리, 동시 갱신 공유, 재시도 횟수 제한 |
| A2 | 로그아웃 / P1 | 연결 오류 상태에서 logout 후 access/refresh token 모두 저장소에 남음 | `lib/services/auth_service.dart:6` — 서버 로그아웃 실패와 무관하게 로컬 토큰·계정 상태 정리 |
| T1 | 타이머 완료 / P1 | complete API가 HTTP 500을 반환했으나 서비스 Future가 정상 완료 | `lib/services/timer/timer_api_service.dart:96`, `lib/core/network/api_client.dart:17` — 상태 코드/응답 성공 여부 확인. 완료 전송 실패 때 로컬 기록을 지우지 않기 |
| T2 | 일시정지 복구 / P1 | PAUSED, 남은 10분, 저장 후 20분 경과 → 서버 complete 호출 및 완료 처리 | `lib/services/timer/timer_service.dart:95` — 일시정지 중 경과 시간을 잔여 시간에서 빼지 않기 |
| T3 | 캐시 없는 타이머 복구 / P1 | 로컬 캐시 없음, 서버 RUNNING/남은 10분 → complete 호출 | `lib/services/timer/timer_service.dart:86,108` — 캐시 없을 때 0초 대신 서버 잔여 시간으로 복구 |
| N1 | 알림 읽음 / P2 | read-all API HTTP 500도 정상 완료로 반환 | `lib/services/notification/notification_api_service.dart:30`, `lib/core/network/api_client.dart:17` — HTTP 실패를 성공과 구분. UI 읽음 표시는 서버 성공 후 변경 |
| N2 | 루틴 저장 / P1 | 서버 응답을 보류했는데 addRoutine Future가 먼저 완료 | `lib/services/notification_setting.dart:36` — 누락된 await 추가. 호출 화면이 서버 성공 전에 닫히지 않도록 실패 표시. 팔로우 설정·삭제도 같은 누락 확인 |
| L1 | 서재 조회 / P2 | HTTP 503을 빈 배열로 반환. UI에서는 실제 빈 서재와 구분 불가 | `lib/services/library_service.dart:166,195` — 실패 상태와 정상 빈 목록을 분리하고 재시도 제공 |
| D1 | 독서 DNA / P1 | 마지막 제출 실패 후 재시도 시 답변 ID가 `[20,30,40,50]`에서 `[20,30,40,50,50]`로 바뀜 | `lib/screens/dna_test/dna_test_page.dart:113` — 제출 시 원본 배열을 누적 수정하지 않고 동일 응답 payload로 재시도 |
| B1 | 주제 책 목록 / P1 | `/books`가 503일 때 짧은 모의 실행 동안 같은 페이지 요청 21회 발생 | `lib/screens/topics/topics_page.dart:133,192` — 실패 시 최소 20권 확보 loop를 종료하고 명시적 재시도/제한된 backoff 사용 |

재현 코드: `test/release_readiness_test.dart`, `test/token_refresh_release_test.dart`. 로컬 fake API 이외 운영 데이터의 생성·수정·삭제는 수행하지 않았다.

## 코드·설정 점검에서 발견한 추가 위험

1. **API HTTP 설정**: `.env`의 BASE_URL이 HTTP IP 주소다. 로그인 비밀번호와 토큰을 전송하는 경로에 암호화가 없다. 올바른 HTTPS 도메인과 인증서로 전환 후 실제 계정 로그인 검증이 필요하다. 임의로 인증서 검증을 끄거나 HTTP 허용 설정을 추가하지 않았다. 릴리스 병합 Manifest에 INTERNET은 있지만 명시적 cleartext 허용은 없었다. 기기에서의 실제 차단 오류까지 재현한 것은 아니다.
2. **토큰 로그 출력**: `auth_service.dart:18`, `splash_screen.dart:32`에서 실제 토큰을 `debugPrint`로 출력하며 release 조건문이 없다. 제거 또는 마스킹 필요. Dio의 기본 LogInterceptor 출력은 설치된 구현에서 assert로 제한되므로 그 로그까지 release 노출이라고 단정하지 않는다.
3. **백그라운드/종료 상태 FCM 클릭**: foreground 로컬 알림 처리만 구현되어 있고 `onMessageOpenedApp`, `getInitialMessage` 처리는 lib 전체에서 찾지 못했다. 해당 상태의 푸시→목적 화면 이동은 별도 구현·기기 검증 필요.
4. **타이머 앱/서비스 동기화**: 화면에서 pause/resume 할 때 foreground task의 `_isPaused`를 변경할 `sendDataToTask`가 없다. manager는 알림만 업데이트한다. 앱 화면 버튼과 알림 버튼의 일시정지 결과를 실기기로 비교해야 한다.
5. **네트워크 실패와 자동 로그인**: refresh 예외를 모두 인증 실패로 취급하고 저장 토큰을 지운다. 일시적인 오프라인/서버 장애를 계정 만료와 구분해야 한다. refresh Dio에는 별도 timeout도 없다.
6. **서재 목록 10권 제한**: 탭은 기본 `size=10` 한 번만 호출하며 페이지 추가 로드가 없다. 11권 이상인 계정의 목록 완전성을 검증해야 한다.
7. **새 인물 이미지 브랜치의 누락 asset**: 별도 브랜치 diff에서 fallback에 `assets/images/person.png`가 지정되지만 해당 브랜치 Git tree와 현 작업 폴더 어디에도 없다. 병합 시 자산 추가 또는 기존 fallback 사용 후 네트워크 이미지 실패·빈 URL·저작권 표시를 테스트해야 한다. 아직 미병합이므로 실행 재현 실패 10개에는 포함하지 않았다.

## 이번에 정리한 테스트 기반

기존 `test/widget_test.dart`는 전체가 주석이라 main 함수 부재로 전체 test command를 실패시켰다. 실제 첫 실행에서 토큰이 없을 때 온보딩으로 이동하는 smoke test로 교체했고 통과했다. 이 수정은 앱 비즈니스 로직을 변경하지 않는다.

## 출시 전에 남은 검증

- 대상 버전 확정: 인물 이미지·저작권 브랜치 포함 여부.
- 서명 key.properties와 실제 업로드 키의 경로·암호 일치. 기존 Play 등록 키와의 일치, versionCode 2 재사용 여부는 Play Console 확인 전이므로 미검증.
- 서버 HTTPS 정상화 후 제공된 계정 로그인, 재실행 로그인 유지, 프로필 저장, 서재 추가/상태 변경/삭제, 유명인 팔로우와 해제. 데이터 변경 테스트는 테스트 계정에서만 진행.
- 실제 이메일 인증·카카오 로그인, 비밀번호 재설정·회원 탈퇴는 별도 시나리오 필요. 현재 검증 완료로 표기하지 않는다.
- Android 알림 허용/거부, 백그라운드·앱 종료 푸시 클릭, 타이머 화면 꺼짐/잠금/강제 종료/오프라인/중복 탭.
- 실제 서명 release AAB 빌드, 내부 테스트 배포 후 설치 및 기능 검증. 스토어 제출·배포는 수행하지 않았다.
- 모든 재현 실패 수정 후 전체 테스트를 다시 실행하고, 자동 테스트 통과와 실제 기기 통과를 각각 기록.
