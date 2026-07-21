# Kerminal

Termius 유사 크로스플랫폼 SSH/터미널 클라이언트. Flutter 단일 코드베이스로 Windows / macOS / Linux / iOS / Android / Web을 지원합니다.

개발 계획은 [PLAN.md](PLAN.md), 배포 절차는 [DEPLOY.md](DEPLOY.md)를 참고하세요.

## 다운로드 / 배포

최신 릴리스: **[Releases 페이지](https://github.com/<org>/kerminal/releases/latest)** · [전체 릴리스](https://github.com/<org>/kerminal/releases)

| 플랫폼 | 아티팩트 | 비고 |
|--------|----------|------|
| Windows | [`.msix`](https://github.com/<org>/kerminal/releases/latest) | 설치 관리자 |
| macOS | [`.dmg`](https://github.com/<org>/kerminal/releases/latest) | Apple 서명·공증 필요 |
| Linux | [`.AppImage` / `.deb`](https://github.com/<org>/kerminal/releases/latest) | |
| Android | [`.apk` / `.aab`](https://github.com/<org>/kerminal/releases/latest) | Play Store: `.aab` |
| Web | [웹 데모](https://<org>.github.io/kerminal/) | UI 전용 (브라우저 제약으로 직접 SSH 불가) |

> 릴리스 아티팩트는 `git tag vX.Y.Z` 푸시 시 [GitHub Actions](.github/workflows/release.yml)가
> 자동으로 빌드해 **드래프트 릴리스**에 첨부합니다. 앱은 [`latest.json`](DEPLOY.md#자동-업데이트-버전-인식--다운로드-안내)
> 매니페스트로 새 버전을 감지합니다.
>
> **`<org>`를 실제 GitHub 조직/사용자명으로 교체**하세요. (다른 호스팅을 쓰면 해당 URL로 변경)

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
