# 로그인·인물·주제 UI 수정 검증 (2026-10-22)

## 수정 사항

| 요청 | 반영 내용 |
| --- | --- |
| 로그인 안내 가운데 정렬 | 비밀번호 재설정·계정 찾기 안내 묶음을 화면 가운데에 배치. 좁은 화면에서 줄이 바뀌어도 가운데 유지 |
| 비밀번호 찾기 확인 | 도메인 선택 후 문자열이 옆으로 넘치던 문제 수정. 계정 찾기 화면은 작은 화면과 키보드에 대응하도록 스크롤 허용 |
| 인물 직업 색상 통일 | 목록·실제 상세 경로·기존 상세 위젯이 공통 JobTag와 색상표 사용 |
| 주제 카테고리 고정 | 스크롤 시 상단 고정. 펼친 메뉴는 현재 카테고리 바로 아래에 표시. 변경 후 결과 첫 행으로 이동 |
| 인물 전체 복원 | 서버 카테고리에 전체가 없어도 맨 앞에 유지. 전체 선택 시 필터 없는 요청. 이전 필터 응답이 늦게 와도 최신 목록 유지 |
| 직업 태그 확대·줄바꿈 | 글자 10→12, 여백 확대. 두 태그가 폭을 넘으면 다음 줄에 배치하고 그리드 행 높이를 맞춤 |

## 자동 테스트

- `flutter test --no-pub --concurrency=1 --reporter expanded`: 전체 **133개 통과**.
- 새 UI 회귀 테스트 **14개**: 320/393 논리 픽셀 × 글자 100/130%, 로그인 정렬, 도메인 선택 및 인증 후 새 비밀번호 입력 UI, 긴 직업 태그 줄바꿈·카드 정렬, 전체 복원·늦은 응답, 목록/상세 색상, 주제 고정·메뉴 위치·필터 결과 위치, 작은 계정 찾기 화면.
- 변경 Dart 파일 11개 분석: 오류/경고 0, 기존 스타일 info 13개 (`withOpacity`, underscore).
- Android debug APK 및 iOS Simulator 빌드 성공. 두 빌드의 환경변수 포함 검사 통과(BASE_URL만 허용).

## 기기 확인

### 삼성 Galaxy S9 (SM-G960N, 실제 서버 조회)

기존 서명과 같은 debug APK를 덮어 설치해 로그인 상태를 유지했다. 인물·주제 공개 목록 조회와 화면 이동으로 확인했다.

- 인물 목록/상세 `기업가` 태그 색상 일치. 목록의 긴 태그가 두 줄로 배치되며 이름 높이 정렬.
- [가수 선택](galaxy-s9-celebrity-filtered.png) 후 전체를 선택해 원래 인물 목록 복원 확인.
- 주제 스크롤 후 카테고리 상단 고정. 메뉴를 펼치면 바로 아래 표시.
- 과학 선택 후 `과학·기술` 결과 첫 행이 카테고리 아래에 표시.
- 팔로우·서재 추가·실제 비밀번호 변경은 수행하지 않았다.

### iPhone 16 Simulator (iOS 18.6, 393×852)

`tool/ui_fixes_qa.dart`에서 실제 화면 위젯에 로컬 API 응답과 이미지 fixture를 연결했다. 인증 메일 발송/인증은 로컬 응답으로만 진행하며 서버 인증 성공을 검증한 결과가 아니다. 별도 XCTest UI Testing 타깃에서 화면 이동과 좌표를 검증했다.

- XCTest 시나리오 통과: 로그인 안내 두 묶음의 화면 중앙 좌표, 비밀번호 찾기 단계 이동, 인물 목록/상세 이동과 필터 복원, 주제 고정 위치 및 메뉴/필터 결과 위치 확인.

## 캡처

| 화면 | iPhone 16 (로컬 데이터) | Galaxy S9 (실제 서버 조회) |
| --- | --- | --- |
| 로그인 안내 | [캡처](iphone-16-login-alignment.png) | — |
| 비밀번호 찾기 | [캡처](iphone-16-password-recovery.png) | — |
| 새 비밀번호 입력 | [캡처](iphone-16-new-password.png) | — |
| 인물 태그 | [캡처](iphone-16-celebrity-tags.png) | [캡처](galaxy-s9-celebrity-tags.png) |
| 상세 태그 | [캡처](iphone-16-celebrity-detail-tags.png) | [캡처](galaxy-s9-celebrity-detail-tags.png) |
| 전체 필터 | [캡처](iphone-16-celebrity-all-filter.png) | [캡처](galaxy-s9-celebrity-all-filter.png) |
| 주제 고정 | [캡처](iphone-16-topics-pinned.png) | [캡처](galaxy-s9-topics-pinned.png) |
| 주제 메뉴 | [캡처](iphone-16-topics-menu.png) | [캡처](galaxy-s9-topics-menu.png) |
| 주제 변경 후 | [캡처](iphone-16-topics-filtered.png) | [캡처](galaxy-s9-topics-filtered.png) |

## 별도 관찰

기본 진입점 `lib/main.dart`로 복원하여 빌드·실행했고 온보딩 화면 표시까지 확인했다. 해당 실행 로그에는 기존 Firebase 초기화 경로에서 `[core/not-initialized] Firebase has not been correctly initialized.`가 출력된다. 앱 화면 실행은 계속되지만 iOS 푸시 알림 초기화 성공은 확인되지 않았다. 이번 5개 UI 수정과 별도인 항목으로 기록한다.

## 재현

```sh
flutter test --no-pub --concurrency=1 test/ui_requested_fixes_test.dart
flutter run --debug --no-pub -d <simulator-id> -t tool/ui_fixes_qa.dart
```

로컬 검증 메뉴에서 로그인·인물·주제 화면을 열어 캡처와 비교한다. 검증 종료 후 기본 진입점 `lib/main.dart`로 다시 실행한다.
