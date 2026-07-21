# Kominal

Termius 유사 크로스플랫폼 SSH/터미널 클라이언트. Flutter 단일 코드베이스로 Windows / macOS / Linux / iOS / Android / Web을 지원합니다.

개발 계획은 [PLAN.md](PLAN.md)를 참고하세요.

## 기술 스택

| 영역 | 패키지 |
|------|--------|
| 프레임워크 | Flutter (Dart) |
| 상태관리 | `flutter_riverpod` |
| 라우팅 | `go_router` |
| SSH/SFTP | `dartssh2` |
| 터미널 | `xterm` |
| 로컬 DB | `drift` + `drift_flutter` (SQLite) |
| 보안 저장소 | `flutter_secure_storage` |

## 아키텍처

Clean Architecture 4레이어. **메타데이터는 DB, 시크릿(비밀번호·개인키)은 OS 보안 저장소**에 분리 저장합니다.

```
lib/
├─ core/          # theme, router 등 횡단 관심사
├─ presentation/  # 화면 (hosts, terminal)
├─ application/   # Riverpod providers / 유스케이스
├─ domain/        # entities, repository 인터페이스
└─ data/          # drift(local), secure vault, ssh service
```

## 개발 환경 설정

```bash
flutter pub get
dart run build_runner build   # drift 코드 생성 (*.g.dart)
flutter run                   # 실행 (기기/플랫폼 선택)
```

### 플랫폼별 요구사항

- **Windows 데스크톱:** 개발자 모드 활성화 필요 (`start ms-settings:developers`) — 플러그인 symlink 지원.
- **Android:** Android SDK cmdline-tools 설치 + `flutter doctor --android-licenses` 승인.
- **iOS / macOS:** macOS + Xcode 필요.
- **Web:** 추가 설정 없이 `flutter run -d chrome`.

## 검증

```bash
flutter analyze
flutter test
```
