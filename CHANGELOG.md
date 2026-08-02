# Changelog

All notable changes to Kerminal are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow semver.

## [0.5.0]

### Changed
- **Windows 배포처가 Microsoft Store로 바뀝니다** — 태그 릴리스에는 더 이상 `.msix`와
  코드사이닝 인증서가 첨부되지 않고, Windows는
  [Microsoft Store](https://apps.microsoft.com/detail/9P23N0L20CTR)에서 받습니다.
  앱 내 업데이트 확인도 Windows에서는 스토어 페이지를 엽니다. 다른 플랫폼(macOS ·
  Linux · Android · Web)은 그대로 GitHub 릴리스에서 받습니다.
- **브랜드 표기 SMIC → Minary** — 회사명이 노출되던 모든 지점을 바꿨습니다: Windows
  실행 파일 버전 정보(CompanyName·저작권), macOS "정보" 창 저작권, MSIX 게시자 표시
  이름, `LICENSE`, 개인정보처리방침. 앱 UI 자체에는 회사명이 표시되는 곳이 없었습니다.
- **패키지 식별자 `kr.smic.kerminal` → `kr.minary.kerminal`** — Android
  applicationId·namespace, iOS/macOS 번들 ID, Linux application ID, MSIX identity.

  > ⚠️ **기존 설치본은 자동 업데이트되지 않습니다.** 식별자가 바뀌면 OS가 완전히 다른
  > 앱으로 인식해 별개로 설치되고, 이전 앱에 저장된 호스트 목록과 시크릿은 새 앱에서
  > 보이지 않습니다. 업그레이드 전에 이전 버전에서 **설정 → 백업 내보내기**로
  > `.kerminal` 파일을 만들고, 새 버전에서 가져오기로 복원하세요.

  > Windows 사이드로딩 설치의 **게시자 표기는 아직 "SMIC"** 입니다. 코드사이닝
  > 인증서(`CN=SMIC`)를 교체하지 않았기 때문이며, 교체 절차와 그 영향은
  > [DEPLOY.md](DEPLOY.md#windows-msix)에 정리했습니다. 스토어 배포본은 스토어가
  > 서명하므로 해당되지 않습니다.

### Added
- **개인정보처리방침** [`PRIVACY.md`](PRIVACY.md) (한국어·영어) — 로컬 저장 항목,
  계정 사용 시 수집 항목, 종단 간 암호화 범위, 삭제 요청 절차.
- **Microsoft Store 제출 자료** [`STORE_SUBMISSION.md`](STORE_SUBMISSION.md) —
  파트너 센터 화면별 입력값, 연령 등급 답변, 등록 정보 문안(ko/en), 인증 메모.

## [0.4.9]

### Fixed
- **모바일에서 탭 전환 불가 수정** — 좁은 화면에서는 탭이 앱바 제목 칸에 갇혀 하나만
  겨우 보였고, 좌우로 스와이프해도 드래그 재정렬 제스처가 가로 스크롤을 가로채
  다른 탭으로 갈 수 없었습니다. 폰 레이아웃에서는 탭이 앱바 아래 전체 폭 줄로
  내려오고, 터치에서는 **길게 누른 뒤에야** 재정렬이 시작돼 스와이프로 탭 줄을
  스크롤할 수 있습니다. 제목(또는 탭 아이콘)을 누르면 전체 세션 목록 시트가 열려
  바로 전환·닫기가 가능하고, 선택된 탭은 자동으로 화면 안으로 스크롤됩니다.
  호스트 목록은 화면을 잡아먹는 300px 사이드바 대신 드로어로 열립니다.
- **앱 전환 후 연결 끊김 자동 복구** — 다른 앱에 갔다 돌아오면 호스트 연결이 끊겨
  있던 문제. 20초 keep-alive로 유휴 연결이 NAT/서버에서 잘리지 않도록 하고, 앱이
  포그라운드로 돌아올 때 세션마다 링크 상태를 확인(ping)해 끊겼으면 **같은 탭과
  스크롤백을 유지한 채** 자동으로 재연결합니다. iOS는 앱이 정지되면 OS가 소켓을
  끊기 때문에 완전한 유지는 불가능하며, 복귀 시 자동 재연결로 이어집니다.
- **숨은 탭이 키보드 포커스를 뺏던 문제** — 여러 세션이 동시에 연결될 때(예: 복귀
  후 일괄 재연결) 보이지 않는 탭이 포커스를 가져가 입력이 엉뚱한 세션으로 가던
  문제를 고쳤습니다.

## [0.4.8]

### Fixed
- **터미널 상단 겹침 수정** — 대상 호스트 헤더 바로 아래에서 터미널 첫 줄이 잘려
  헤더와 겹쳐 보이던 문제를 고쳤습니다. 헤더 아래에 터미널 배경색 여백과 구분선을
  두어 깔끔히 분리했습니다.

## [0.4.7]

### Changed
- **탭 선택 시 자동 입력 포커스** — 탭을 선택하면 해당 터미널에 키보드 포커스가
  자동으로 가서, 터미널을 따로 클릭하지 않아도 바로 입력할 수 있습니다.

## [0.4.6]

### Changed
- **상단 탭 좌측 정렬** — 터미널 탭이 우측이 아니라 왼쪽부터 배치되고, 넘칠 때
  오른쪽으로 스크롤됩니다.

## [0.4.5]

### Added
- **그룹 단위 공유** — 호스트 목록의 그룹 헤더에 공유 버튼(⤴)을 추가했습니다. 누르면
  그 그룹에서 내가 소유한 호스트 전체를 한 동료에게 한 번에 초대할 수 있고, 그룹
  전체에 공유된 동료 목록과 일괄 공유 취소도 제공합니다. (각 호스트는 상대가
  "수신"해야 목록에 추가되는 기존 초대 방식 그대로.)

## [0.4.4]

### Changed
- **탭 드래그로 순서 변경** — 터미널 탭을 좌우로 드래그해 원하는 순서로 재배치할 수
  있습니다(드롭 위치에 하이라이트 표시, 선택된 탭 유지).
- **탭 우측 ＋ → 호스트 추가** — 탭 오른쪽의 ＋ 버튼이 이제 호스트 추가 화면을
  엽니다(기존 빠른 연결 대신).

## [0.4.3]

### Changed
- **앱 아이콘 리디자인(방사형)** — 중심의 터미널 프롬프트 `>_`에서 빛이 사방으로
  뻗어나가는 방사형 디자인으로 교체해 확장·생동감을 강조했습니다.

## [0.4.2]

### Changed
- **새 앱 아이콘** — 단조로운 기존 아이콘을 시안→에메랄드→라임의 활기찬 그라디언트에
  터미널 프롬프트 `>_`(노란 커서 스파크)를 얹은 새 아이콘으로 교체했습니다. 플랫폼
  아이콘은 릴리스 빌드에서 `assets/icon/app_icon.png`로부터 자동 재생성됩니다.

## [0.4.1]

### Changed
- **터미널 워크스페이스에 설정 아이콘** — 호스트에 접속해 터미널 탭이 열린
  상태에서도 상단 우측(＋ 옆)에 설정 아이콘을 표시해, 호스트 목록으로 돌아가지
  않고 바로 설정을 열 수 있습니다.

## [0.4.0]

### Changed
- **공유는 초대 → 수신 방식으로** — 호스트를 공유하면 상대에게 바로 목록에 뜨지
  않고, 먼저 **초대 메시지**로 표시됩니다. 상대가 **"수신"**을 눌러야 자신의 목록에
  추가됩니다("거절"하면 접근이 회수됩니다). 소유자는 공유 창에서 각 대상의 상태를
  "수신 대기 / 수신함"으로 확인할 수 있습니다.
- **잘못된 초대 대상 안내** — 초대한 이메일로 가입된 Kerminal 계정이 없으면 소유자
  화면에 명확히 표시해 오기입을 바로잡을 수 있습니다.

## [0.3.2]

### Changed
- **호스트 더블클릭 접속** — 단일 클릭 오접속을 막기 위해 호스트는 더블클릭
  (더블탭)할 때만 접속합니다. (메인 목록·사이드바 공통)

## [0.3.1]

### Changed
- **터미널 워크스페이스** — 접속하면 호스트 목록이 좌측 사이드바로 전환(☰ 토글),
  접속 탭은 우측 상단에 표시. 탭 우클릭 → 컨텍스트 메뉴에서 Duplicate로 같은
  호스트를 새 탭으로 복제.
- **오기입 방지** — 세션마다 고유 색상을 탭·터미널에 연동하고, 터미널 상단에 현재
  접속 대상(호스트) 헤더를 표시해 어느 탭에 입력 중인지 명확히 했습니다.
- **소유자 배지 완화** — 소유 호스트 표시를 은은한 회색 아이콘으로 줄였습니다.

## [0.3.0]

### Added
- **소유자 배지** — 호스트 목록에서 내가 소유한 호스트에 "소유자" 배지를 표시하고,
  공유한 경우 "공유함"을 함께 보여줍니다. 공유받은 호스트는 "공유받음 · {소유자}"로
  구분됩니다. (수정은 소유자만 — 공유받은 호스트는 읽기전용.)

## [0.2.9]

### Fixed
- **macOS 실행 불가 + 동기화 -34018 근본 해결** — 0.2.8에서 추가한
  `keychain-access-groups` 엔타이틀먼트가 ad-hoc 서명과 충돌해 앱이 실행되지 않던
  문제를 되돌리고, macOS에서는 OS 키체인 대신 **AES-256-GCM 암호화 파일**에 비밀을
  저장하도록 변경했습니다(Apple 팀 서명 없이도 동작). Windows/Linux/모바일은 기존
  OS 보안 저장소를 그대로 사용합니다.

## [0.2.8]

### Fixed
- **macOS 동기화 키체인 오류(-34018) 해결** — `keychain-access-groups` 엔타이틀먼트를
  추가해 flutter_secure_storage가 macOS 키체인에 접근할 수 있게 했습니다. 이게 없어
  동기화 시 secret 저장/읽기가 `errSecMissingEntitlement`로 실패했습니다. (Windows는
  영향 없음.)

## [0.2.7]

### Fixed
- **동기화 42501 최종 해결** — 클라우드 업로드에 upsert 대신 신규는 INSERT, 기존은
  UPDATE를 사용하도록 변경. PostgREST의 upsert가 RLS WITH CHECK 평가에 걸리던
  문제를 우회합니다(서버 측 추가 설정 불필요).

## [0.2.6]

### Fixed
- **동기화 RLS 42501 확정 수정** — 호스트 업로드 시 `owner_id`를 클라이언트가 보내지
  않고, 서버가 `auth.uid()`로 자동 설정하도록 변경. 세션/토큰 상태와 무관하게 RLS를
  통과합니다. (기존 Supabase 프로젝트는 `owner_id` 컬럼에 `default auth.uid()`를
  한 번 적용해야 합니다 — README 참고.)

## [0.2.5]

### Fixed
- **동기화 실패(RLS 42501) 해결** — 호스트 업로드 시 `owner_id`를 현재 로그인 세션
  사용자에서 가져오도록 바꿔, 서버의 `auth.uid()`와 항상 일치하도록 했습니다.
  (캡처된 값이 세션과 어긋나면 "row-level security policy" 위반이 났습니다.)

## [0.2.4]

### Added
- **호스트 공유 (P3)** — 특정 호스트를 동료 이메일로 공유. 콘텐츠 키를 동료 공개키로
  봉인해 서버는 평문을 모른 채 공유됩니다. 공유받은/공유한 호스트에 라벨 표시.
- **공유 호스트 읽기전용 + 복사 (P4)** — 공유받은 호스트는 읽기전용이며, "내 목록으로
  복사"해 자기 소유 호스트로 만든 뒤 자유롭게 편집·재공유. Realtime으로 공유·변경이
  자동 반영됩니다.
- **변경 이력 + 롤백 + 휴지통 (P5)** — 호스트 추가·수정·삭제 이력을 암호화해 기록하고,
  버전별로 롤백하거나 삭제한 호스트를 휴지통에서 복원할 수 있습니다.

## [0.2.1]

### Added
- **접속 리스트 클라우드 동기화 (P2)** — 로그인·잠금 해제 상태에서 호스트를
  종단간 암호화해 Supabase에 업로드하고, 기기 간에 동기화합니다. 호스트마다 랜덤
  콘텐츠 키로 암호화하고 그 키는 내 공개키로만 봉인되므로 서버는 평문을 볼 수
  없습니다. 저장/삭제 시 자동 업로드, 잠금 해제 시 자동 내려받기, 계정 화면에서
  "Sync hosts now"로 수동 동기화. (자격증명이 없는 빌드는 로컬 전용.)

## [0.2.0]

### Added
- **계정 & 종단간 암호화 신원 (P1)** — Supabase 이메일/비밀번호 로그인과 계정별
  X25519 키쌍. 개인키는 별도 패스프레이즈로 봉인해 저장하고, 잠금 해제 시에만
  메모리에 올라갑니다. 설정 → Account & Sync에서 가입/로그인/잠금 해제.
  (클라우드 동기화·공유는 다음 단계에서 이 신원 위에 얹습니다. 자격증명이 없는
  빌드는 기존처럼 로컬 전용으로 동작합니다.)

## [0.1.9]

### Fixed
- **Windows MSIX 업데이트 불가(0x80073CFB) 해결** — `msix_version`이 `0.1.5.0`으로
  하드코딩돼 있어 릴리스마다 패키지 버전이 동일했습니다. Windows는 "같은 버전인데
  내용이 다름"으로 재설치를 거부했습니다. 이제 CI가 pubspec `version`에서 4자리
  MSIX 버전(`X.Y.Z+B` → `X.Y.Z.B`)을 계산해 매 릴리스마다 증가시키므로 제자리
  업데이트가 됩니다. (기존 설치본은 한 번 제거 후 재설치 필요.)

## [0.1.8]

### Fixed
- **업데이트 확인이 반응 없던 문제** — 체크 실패 시 모든 예외를 삼켜 `null`로
  바꾸던 탓에 성공/실패/최신 어떤 메시지도 안 떠 "먹지 않는" 것처럼 보였습니다.
  이제 네트워크/파싱 실패가 UI 에러로 표면화됩니다("Update check failed: …").
  (macOS에서 이전 샌드박스 빌드가 아웃바운드 네트워크를 막아 조용히 실패하던 것이
  이 방식으로는 드러납니다. 네트워크 차단 자체는 0.1.6에서 해결됨.)

## [0.1.7]

### Fixed
- **macOS 호스트 저장 실패(-34018) 실제 해결** — `flutter_secure_storage`가
  기본으로 쓰는 데이터 보호 키체인은 Apple 팀 서명(`application-identifier`)이
  있어야만 접근됩니다. ad-hoc 직접 배포에는 그게 없어 실패했습니다.
  `usesDataProtectionKeychain: false`로 전환해 엔타이틀먼트가 필요 없는 파일 기반
  로그인 키체인을 쓰도록 변경했습니다. (0.1.6의 App Sandbox 해제만으로는 부족했음.)

## [0.1.6]

### Fixed
- **macOS App Sandbox 해제** — 직접 배포(ad-hoc) 구성에서 키체인 접근과 SSH
  아웃바운드 연결을 허용하기 위한 변경. (키체인 -34018의 완전한 해결은 0.1.7 참고.)

## [0.1.5]

### Added
- **Encrypted backup & share** — export all hosts (including secrets) to a
  passphrase-encrypted `.kerminal` file (PBKDF2 + AES-256-GCM) and import it
  elsewhere with the same passphrase. Safe to share via Google Drive, etc.
  (Settings → Backup & Share).

## [0.1.4]

### Added
- **Collapsible groups** — tap a group header to expand/collapse its hosts;
  headers show the host count.

## [0.1.3]

### Changed
- **Update check wired up** — the in-app update check now defaults to the GitHub
  "latest release" manifest, and each release publishes a `latest.json`. Older
  versions detect new releases automatically (Settings → About & Updates).

## [0.1.2]

### Added
- **Group autocomplete** — the group field suggests existing groups; hosts with
  no group fall under the default group ("기본").

### Changed
- **Optional account** — username may be left blank; it defaults to the current
  OS user on connect (like the `ssh` CLI).
- **App-private storage** — the database now lives in the app support directory
  instead of Documents, so it is removed on uninstall (a fresh install starts
  empty) and is no longer synced to OneDrive. Existing data is moved over once
  on first launch.

## [0.1.1]

### Changed
- Windows MSIX is now signed with a self-signed code-signing certificate
  (`CN=SMIC`). The public cert (`kerminal-codesign.cer`) ships with the release;
  trust it once ("Trusted People") to install without the unknown-publisher
  warning.

## [0.1.0] (MVP)

First feature-complete MVP: a cross-platform SSH/terminal client.

### Added
- **SSH terminal** — live shell over `dartssh2` rendered with `xterm`, password
  and SSH-key authentication, connection status (connecting/connected/failed/
  closed) with reconnect.
- **Host management** — create/edit/delete saved hosts with grouping and search;
  one-click connect. Secrets (passwords, private keys, passphrases) are stored in
  the OS-backed secure vault, never in the database.
- **SSH key generation** — generate Ed25519 keys in-app; copy the public key for
  `authorized_keys`.
- **known_hosts verification** — SHA256 host-key fingerprints with a trust prompt
  on first connect and a man-in-the-middle warning if a key changes.
- **Multi-session tabs** — multiple concurrent terminals with per-session
  reconnect; scrollback preserved when switching tabs.
- **Special-key toolbar** — Esc/Tab/^C/^D/^L/arrow keys (essential on mobile).
- **Settings** — theme (system/light/dark) and terminal font size, persisted.

### Platforms
- Windows, macOS, Linux, iOS, Android, Web (single Flutter codebase).

[0.4.0]: https://github.com/knoxxr/kerminal/releases/tag/v0.4.0
[0.3.2]: https://github.com/knoxxr/kerminal/releases/tag/v0.3.2
[0.3.1]: https://github.com/knoxxr/kerminal/releases/tag/v0.3.1
[0.3.0]: https://github.com/knoxxr/kerminal/releases/tag/v0.3.0
[0.1.5]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.5
[0.1.4]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.4
[0.1.3]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.3
[0.1.2]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.2
[0.1.1]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.1
[0.1.0]: https://github.com/knoxxr/kerminal/releases/tag/v0.1.0
