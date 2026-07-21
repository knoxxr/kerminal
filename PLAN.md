# Kerminal — 개발 계획서

> Termius 유사 크로스플랫폼 SSH/터미널 클라이언트
> 작성일: 2026-07-21

## 1. 목표

Termius와 유사한 크로스플랫폼 SSH 클라이언트를 개발한다.

- **타겟 플랫폼:** 데스크톱(Windows / macOS / Linux) + 모바일(iOS / Android)
- **MVP 핵심 기능:** ① SSH 접속 + 터미널 에뮬레이션, ② 호스트/자격증명 관리
- **원칙:** 단일 코드베이스, 로컬 우선(오프라인 동작), 자격증명 보안 최우선

## 2. 기술 스택

| 영역 | 선택 | 비고 |
|------|------|------|
| 프레임워크 | **Flutter (Dart)** | 5개 플랫폼 단일 코드베이스 |
| SSH/SFTP | `dartssh2` | 순수 Dart, 네이티브 의존 없음 |
| 터미널 UI | `xterm.dart` | VT100/xterm 에뮬레이션 |
| 로컬 DB | `drift` (SQLite) | 호스트/그룹/설정 저장 |
| 보안 저장소 | `flutter_secure_storage` | OS 키체인(macOS/iOS), Keychain/Keystore, DPAPI(Win) 연동 |
| 상태관리 | `riverpod` | 테스트 용이, 의존성 주입 |
| 라우팅 | `go_router` | 선언적 라우팅 |

### 대안
- 데스크톱 전용으로 축소 시: **Tauri v2 (Rust + React)** — 번들 크기·성능 우위.
- 모바일 지원이 최우선이면 Flutter 유지가 최적.

## 3. 아키텍처 (레이어)

```
┌─────────────────────────────────────────┐
│  Presentation (Flutter Widgets)          │  화면/터미널 뷰
├─────────────────────────────────────────┤
│  Application (Riverpod Providers)        │  세션 관리, 유스케이스
├─────────────────────────────────────────┤
│  Domain (Entities / Repositories 인터페이스)│  Host, Credential, Session
├─────────────────────────────────────────┤
│  Data                                    │
│   ├─ SSH Service (dartssh2)              │  연결/스트림
│   ├─ Local DB (drift)                    │  메타데이터
│   └─ Secure Vault (secure_storage)       │  비밀/키 (암호화)
└─────────────────────────────────────────┘
```

**보안 원칙:** 비밀번호·개인키는 절대 평문 DB 저장 금지. 메타데이터(호스트명/포트/사용자)는 DB, 시크릿은 Secure Storage에 분리 저장하고 참조 ID로 연결.

## 4. 개발 단계 (마일스톤)

### Phase 0 — 프로젝트 셋업 (1주) ✅ 완료
- [x] Flutter 프로젝트 생성, 5개 플랫폼 빌드 확인 (web 빌드 검증)
- [x] 폴더 구조(Clean Architecture) + Riverpod/드리프트 스캐폴딩
- [x] CI(GitHub Actions): 포맷·분석·테스트, 플랫폼별 빌드
- [x] 앱 이름(kerminal) / org(kr.smic) 확정 — 아이콘은 후속

### Phase 1 — 터미널 코어 (2주) ✅ 완료
- [x] `xterm.dart` 터미널 위젯 통합, 스크롤백(10k)
- [x] `dartssh2`로 비밀번호 + SSH 키 인증 접속
- [x] PTY 연결: 키 입력 → SSH, 출력 → 터미널 렌더링
- [x] 연결 상태(연결중/성공/실패/종료) 처리 및 에러 표시
- **완료 기준 충족:** 로컬 Docker SSH 서버로 실접속·명령 실행 검증
  (비밀번호·키 인증 양쪽, `whoami`/`echo` 출력 확인)

### Phase 2 — 호스트/자격증명 관리 (2주) ✅ 완료
- [x] Host 엔티티 CRUD (이름/주소/포트/사용자/그룹) — 추가/편집/삭제 폼
- [x] SSH 키 가져오기(paste) + 시크릿 저장소 저장 (생성은 후속 — dartssh2 파싱만 지원)
- [x] 공개키/비밀번호 인증 선택, 비밀은 전부 SecureVault
- [x] 호스트 목록 UI(그룹 헤더/검색), 원클릭 접속
- **완료 기준 충족:** 저장된 호스트 탭 → Vault에서 자격증명 읽어 즉시 접속
  (docker 실서버 e2e 통과)

### Phase 3 — 세션 UX & 안정화 (2주) ✅ 완료
- [x] 다중 세션(탭) + 세션별 재연결 (IndexedStack로 스크롤백 유지)
- [x] known_hosts 지문 검증 및 신뢰/변경(MITM) 경고 프롬프트 — TOFU 대체
- [x] 특수키 툴바(Esc/Tab/^C/^D/^L/방향키)
- [x] 테마(시스템/라이트/다크) + 폰트 크기 설정 (영속화)
- **완료 기준 충족:** MVP 품질 — analyze/test/web + docker 실서버 e2e 통과

### Phase 4 — 배포 (1주) ✅ 구성 완료
- [x] 전 플랫폼 앱 아이콘 (flutter_launcher_icons, 소스 assets/icon/app_icon.png)
- [x] 데스크톱 패키징 구성: Windows MSIX(msix), Linux deb/AppImage·macOS DMG(flutter_distributor)
- [x] Android 릴리스 서명 구성 (key.properties, build.gradle.kts) + APK/AAB
- [x] 태그 기반 GitHub Actions 릴리스 워크플로 (전 플랫폼 아티팩트 → 드래프트 릴리스)
- [x] 버전 체계, LICENSE, CHANGELOG, DEPLOY.md
- [ ] 실제 코드사이닝/스토어 제출 — **사용자 인증서·계정 필요** (DEPLOY.md 참고)
- [ ] 자동 업데이트(데스크톱) 채널 — 후속 (DEPLOY.md에 방안 기술)

**총 MVP 예상: 약 8주 (1~2인 기준)**

## 5. 로드맵 (MVP 이후)
- SFTP 파일 브라우저 (드래그앤드롭)
- 포트 포워딩 (로컬/원격/다이내믹)
- 명령 스니펫 / 스니펫 실행
- 기기 간 동기화(E2E 암호화) — 자체 백엔드 또는 클라우드 옵션
- 세션 로깅, SSH 에이전트 포워딩, 점프 호스트(ProxyJump)
- Mosh 지원, 텔넷/시리얼

## 6. 주요 리스크
| 리스크 | 대응 |
|--------|------|
| 자격증명 유출 | Secure Storage 분리 저장, 평문 금지, 화면 캡처 차단(모바일) |
| 터미널 호환성(VT 이스케이프) | `xterm.dart` + 실서버 회귀 테스트 스위트 |
| Flutter 데스크톱 성숙도 | 조기에 3개 데스크톱 OS 빌드 검증, 네이티브 채널 대비 |
| 스토어 심사(원격 접속 앱) | 정책 사전 검토, 사용 목적 명확화 |
| 동기화 보안 설계 | MVP 제외, 별도 설계 단계에서 E2E 암호화 채택 |

## 7. 다음 액션
1. 스택/계획 확정 → `flutter create` 로 Phase 0 시작
2. 앱 이름/번들 ID 확정 (`kerminal`?)
3. Phase 1 스파이크: `dartssh2` + `xterm.dart` 접속 PoC 1개 작성
