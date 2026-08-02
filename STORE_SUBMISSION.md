# Microsoft Store 제출 자료 (파트너 센터 입력값)

Kerminal의 Microsoft Store(파트너 센터) 제출 화면에 그대로 붙여넣을 수 있는 값들을
화면 순서대로 정리한 문서입니다. 값은 `v0.4.9` (pubspec `0.4.9+33`) 기준.

> **먼저 읽기:** [§0 제출 전 필수 수정](#0-제출-전-필수-수정-현재-패키지는-거부됨) 두 가지를
> 고치지 않으면 패키지 업로드 단계에서 바로 거부됩니다.

---

## 0. 제출 전 필수 수정 (현재 패키지는 거부됨)

### (1) 패키지 ID / 게시자 — 스토어가 발급한 값으로 교체

현재 `pubspec.yaml`의 값은 자체 배포(사이드로딩)용입니다.

| msix_config 항목 | 현재 값 | 스토어 제출 값 |
|---|---|---|
| `identity_name` | `kr.minary.kerminal` | 파트너 센터 → 제품 → **제품 ID → 패키지 ID → 패키지/ID/이름**<br>(예: `12345Minary.Kerminal`) |
| `publisher` | `CN=SMIC` | 같은 화면의 **패키지/ID/게시자**<br>(예: `CN=A1B2C3D4-...-9F8E7D6C5B4A`) |
| `publisher_display_name` | `minary` | 계정의 **게시자 표시 이름** — 대소문자까지 일치해야 함 (실제 업로드에서 `SMIC` ≠ `minary` 오류 확인) |

세 값은 **한 글자도 다르면 안 됩니다.** 파트너 센터에서 앱 이름을 예약한 뒤에 확인 가능합니다.

### (2) 버전의 마지막 자리는 반드시 `0`

스토어는 MSIX 버전의 **네 번째(리비전) 자리를 예약**하며 `0`이 아니면 거부합니다.
릴리스 CI는 `X.Y.Z+B` → `X.Y.Z.B` (지금은 `0.5.0.34`)로 만들기 때문에
**GitHub 릴리스에 붙는 msix는 스토어에 올릴 수 없습니다.**

- 스토어용은 `--version 0.5.0.0`으로 따로 빌드하고, 다음 제출은 `0.5.1.0`처럼 앞 세 자리를 올립니다.
- 스토어 제출본은 서명하지 않습니다(스토어가 서명). `--store`를 쓰면
  `install_certificate`/자체 서명 인증서는 무시됩니다.

### (2-1) 스토어용 패키지 만드는 법

MSIX는 **Windows에서만** 빌드됩니다. 맥/리눅스만 쓴다면 GitHub Actions의
**Store package (MSIX)** 워크플로를 Actions 탭에서 `Run workflow`로 실행하세요
(`.github/workflows/store-package.yml`). 위 표의 세 값 + 버전을 입력받아 서명 없는
스토어용 패키지를 만들고, **업로드 전에 매니페스트의 Identity/Publisher/Version/
PublisherDisplayName을 로그에 출력**해 확인시켜 줍니다. 결과물은
`kerminal-store-msix` 아티팩트로 내려받습니다.

Windows PC에서 직접 만들 경우:

```powershell
dart run msix:create --store --version 0.5.0.0 `
  --identity-name "<파트너 센터 패키지/ID/이름>" `
  --publisher "<파트너 센터 패키지/ID/게시자>" `
  --publisher-display-name "minary" `
  --windows-build-args "--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
```

### (3) 아키텍처 / 최소 OS 확인

- 현재 CI 산출물은 **x64 전용**입니다(ARM64 미빌드). ARM 기기에서는 에뮬레이션으로 동작합니다.
- 최소 OS: **Windows 10 버전 1809 (10.0.17763.0)** — Flutter 데스크톱 요구사항이자 msix 기본값.
- 선언 기능(capability): `pubspec.yaml`에는 `internetClient`만 적었지만, msix 패키지가
  데스크톱 앱에 필요한 **`runFullTrust`(제한된 기능)** 를 자동으로 추가합니다.
  업로드 시 다음 **경고**가 뜹니다 — 오류가 아니므로 제출은 가능합니다:

  > 다음 제한된 기능은 앱에서 사용하기 전에 승인을 받아야 합니다. runFullTrust.

  Win32 데스크톱 앱을 MSIX로 포장하면 정상적으로 요구되는 기능이며, 심사에서 사유를
  묻습니다. §9 인증 메모에 설명을 넣어 두었습니다.

---

## 1. 앱 이름 예약 (제품 만들기)

| 항목 | 값 |
|---|---|
| 제품 유형 | **앱** |
| 예약할 이름 | `Kerminal` |
| 대체 후보(선점 시) | `Kerminal SSH`, `Kerminal - SSH Client`, `Kerminal Terminal` |

---

## 2. 가격 및 사용 가능 여부

| 항목 | 값 |
|---|---|
| 기본 가격 | **무료** |
| 무료 평가판 | 없음 |
| 시장 | **모든 시장** (수출 규제상 문제 없음 — 표준 SSH 클라이언트) |
| 표시 여부 | 스토어에서 검색·찾아보기 가능 |
| 게시 일정 | 인증 통과 즉시 (또는 수동 게시) |
| 조직 라이선스 | 볼륨 구매 허용 안 함(기본값 유지) |

---

## 3. 속성

| 항목 | 값 |
|---|---|
| 범주 | **개발자 도구(Developer tools)** |
| 하위 범주 | **네트워킹(Networking)** |
| 개인정보처리방침 URL | **필수** — `https://github.com/knoxxr/kerminal/blob/main/PRIVACY.md` (§8 참조) |
| 웹사이트 | `https://github.com/knoxxr/kerminal` |
| 지원 연락처 정보 | `https://github.com/knoxxr/kerminal/issues` (또는 `kbkim@smic.kr`) |

### 제품 선언 (체크박스 7개)

파트너 센터가 3·4·5번을 기본으로 켜 둡니다. **4번과 5번은 꺼야 합니다.**

| # | 항목 | 체크 | 이유 |
|---|---|---|---|
| 1 | 사용자가 구매할 수 있지만 Store 상거래 시스템은 사용할 수 없음 | ☐ 해제 | 무료 앱, 외부 결제 없음 |
| 2 | 접근성 지침을 준수하도록 테스트됨 | ☐ 해제 | 접근성 검증을 한 적 없음. 체크하면 허위 신고 + 접근성 필터 검색에 노출돼 사용자 불만으로 이어짐 |
| 3 | 다른 드라이브/이동식 미디어에 설치 가능 | ☑ 유지 | 일반 앱이라 제한할 이유 없음 |
| 4 | Windows가 이 제품의 데이터를 **OneDrive 자동 백업에 포함** | ☐ **해제** | SSH 접속 대상 목록(서버 주소·계정)이 사용자 동의 없이 클라우드로 복사됨. 앱에 이미 패스프레이즈 암호화 백업이 있고, Windows가 보호한 시크릿은 다른 PC에서 복호화도 안 돼 복원이 반쪽이 됨 |
| 5 | Windows 10/11 기능으로 **게임 클립 녹화·브로드캐스트** 허용 | ☐ **해제** | 게임 범주 전용 선언(경고 문구 참조). 개발자 도구에는 무의미하고, 터미널 화면 녹화를 권장하는 신호로 읽힐 이유도 없음 |
| 6 | 펜 및 잉크 입력 지원 | ☐ 해제 | 필기/잉크 입력 기능 없음 |
| 7 | 생성형 AI 기능 통합 | ☐ 해제 | AI 기능 없음 |

### 시스템 요구 사항

**원칙: "최소 하드웨어" 칸은 비워 둡니다.** 최소로 표시한 항목을 고객 기기가 충족하지
못하면 스토어가 **다운로드 전 경고를 띄우고, 그 고객은 앱을 평가·리뷰할 수 없게**
됩니다. 권장 항목에는 경고가 없습니다. Kerminal은 특별한 하드웨어가 없어도 동작하므로
최소 요구 사항을 걸어서 얻을 것이 없습니다.

| 기능 | 최소 | 권장 | 이유 |
|---|---|---|---|
| 터치 스크린 | ☐ | ☐ | 터치로도 쓸 수 있지만 필요·권장 사항은 아님 |
| **키보드** | ☐ | **☑ 권장** | 터미널이므로 물리 키보드가 훨씬 편함. 다만 Windows 터치 키보드도 키 이벤트를 만들어 주므로 **최소로 걸면 안 됨** — 태블릿 사용자가 경고를 받고 리뷰도 못 하게 됨 |
| 마우스 | ☐ | ☐ | 탭·버튼 모두 터치로 조작 가능 |
| 카메라 / NFC HCE / NFC 근접 / Bluetooth LE / 전화 통신 / 마이크 | ☐ | ☐ | 사용하지 않음 |
| Xbox 컨트롤러·게임패드 / MR 모션 컨트롤러 / MR 헤드셋 | ☐ | ☐ | 사용하지 않음 |
| 메모리 | 지정되지 않음 | 지정되지 않음 | Flutter 데스크톱 앱으로 가벼움. 수치를 걸면 경고만 유발 |
| DirectX | 지정되지 않음 | 지정되지 않음 | 특정 DirectX 레벨을 요구하지 않음(소프트웨어 렌더링으로도 동작) |
| 비디오 메모리 | 지정되지 않음 | 지정되지 않음 | 전용 GPU 불필요 |
| 프로세서 | 비움 | 비움 | 아키텍처(x64)는 패키지 매니페스트가 이미 강제함 |
| 그래픽 | 비움 | 비움 | 별도 요구 사항 없음 |

> OS 최소 버전(**Windows 10 1809 / 10.0.17763.0**)과 x64 아키텍처는 이 화면이 아니라
> MSIX 매니페스트에서 자동으로 반영됩니다. 여기에 중복 입력할 필요가 없습니다.

---

## 4. 연령 등급 (IARC 설문) — 답변 가이드

개발자 도구이므로 폭력/성적 콘텐츠/도박 관련 항목은 전부 **아니요**. 아래 두 항목만 주의:

| 설문 항목 | 답 | 이유 |
|---|---|---|
| 사용자가 제한 없이 인터넷에 접근할 수 있습니까 | **예** | 사용자가 임의의 SSH 서버에 접속 가능 |
| 사용자 간 콘텐츠 공유/커뮤니케이션 기능이 있습니까 | **예** | 계정 사용 시 동료에게 호스트 정보 공유(초대) 가능 |
| 개인정보를 수집·공유합니까 | **예** | 계정 가입 시 이메일 주소 (§8 참조) |
| 디지털 구매 | **아니요** | |

→ 예상 등급: **3세 이상 / Everyone** 수준(위 항목들은 등급을 올리지 않고 표시 문구만 추가됨).

---

## 5. 스토어 등록 정보 — 한국어(ko-KR)

### 설명 (최대 10,000자)

```
Kerminal은 Windows, macOS, Linux, Android, iOS에서 똑같이 동작하는 SSH 터미널
클라이언트입니다. 서버 한 대든 수십 대든, 탭으로 열어 한 화면에서 다룹니다.

■ 탭으로 여러 서버를 동시에
접속할 때마다 새 탭이 열리고, 탭마다 고유 색상이 붙어 지금 어느 서버에 명령을
치고 있는지 헷갈리지 않습니다. 탭은 드래그로 순서를 바꾸고, 같은 서버로 세션을
하나 더 열 수도 있습니다. 스크롤백 1만 줄은 탭을 오가도 그대로 유지됩니다.

■ 자격증명은 OS 보안 저장소에
호스트명·포트·사용자 같은 메타데이터는 로컬 DB에, 비밀번호와 SSH 개인키는
Windows 자격 증명 관리자(다른 플랫폼은 키체인/키스토어)에 분리해서 저장합니다.
평문 파일로 남기지 않습니다.

■ 호스트 키 검증
처음 보는 서버는 지문(fingerprint)을 보여주고 신뢰 여부를 묻습니다. 이미 신뢰한
서버의 키가 바뀌면 중간자 공격 가능성을 경고합니다.

■ 호스트 관리
그룹으로 묶고, 검색으로 찾고, 복제해서 비슷한 서버를 빠르게 추가합니다. 저장하지
않고 한 번만 접속하는 빠른 연결도 지원합니다.

■ 암호화 백업
호스트 전체를 패스프레이즈로 암호화한 .kerminal 파일로 내보내고 다른 기기에서
복원합니다.

■ 선택적 계정 동기화와 팀 공유
계정을 만들면 여러 기기에서 호스트 목록을 동기화하고, 동료에게 호스트나 그룹을
초대 형식으로 공유할 수 있습니다. 호스트 정보는 기기에서 AES-256-GCM으로 암호화한
뒤 업로드되므로 서버는 평문을 볼 수 없습니다. 계정 없이 로컬 전용으로만 써도
모든 접속 기능이 그대로 동작합니다.

■ 그 외
xterm 호환 터미널 에뮬레이션, Ctrl·Alt·방향키·Tab·Esc 특수키 툴바, 라이트/다크
테마, 글꼴 크기 조절, 새 버전 알림.

문의와 버그 제보: https://github.com/knoxxr/kerminal/issues
```

### 앱 기능 (최대 20개 · 각 200자)

```
탭 기반 다중 SSH 세션 (탭별 색상 구분, 드래그 재정렬, 세션 복제)
비밀번호 및 SSH 키 인증 (패스프레이즈 지원)
자격증명을 Windows 보안 저장소에 분리 보관
호스트 키(fingerprint) 검증 및 키 변경 경고
호스트 그룹 관리와 검색
저장 없이 접속하는 빠른 연결
xterm 호환 터미널 · 1만 줄 스크롤백
특수키 툴바 (Ctrl / Alt / 방향키 / Tab / Esc)
패스프레이즈로 암호화된 백업 내보내기·가져오기
선택적 계정 동기화 — 종단 간 암호화(AES-256-GCM)
동료와 호스트·그룹 공유 (초대 후 수신 방식)
라이트/다크 테마와 글꼴 크기 조절
Windows · macOS · Linux · Android · iOS 동일 사용 경험
```

### 짧은 설명 (최대 1,000자)

```
탭으로 여러 서버에 동시에 접속하는 크로스플랫폼 SSH 터미널 클라이언트입니다.
자격증명은 Windows 보안 저장소에 보관하고, 호스트 키 검증과 암호화 백업,
선택적 종단 간 암호화 동기화를 지원합니다.
```

### 이 버전의 새로운 기능 (최대 1,500자)

```
0.4.9
- 모바일에서 탭이 하나만 보이고 전환되지 않던 문제 수정
- 앱을 전환했다 돌아왔을 때 끊긴 SSH 연결을 스크롤백을 유지한 채 자동 재연결
- 연결 완료 시 숨은 탭이 키보드 포커스를 가져가던 문제 수정
- 유휴 연결이 NAT/서버에서 끊기지 않도록 20초 keep-alive 추가
```

### 검색어 (최대 7개 · 각 30자, 비공개)

```
ssh
ssh 클라이언트
터미널
remote shell
서버 관리
ssh client
terminal emulator
```

### 저작권 및 상표 정보 (최대 200자)

```
© 2026 Minary. All rights reserved.
```

### 추가 라이선스 조건

```
본 소프트웨어는 Minary의 독점(proprietary) 소프트웨어입니다.
전체 조건: https://github.com/knoxxr/kerminal/blob/main/LICENSE
```

### 개발자 (Developed by)

```
Minary
```

---

## 6. 스토어 등록 정보 — 영어(en-US)

### Description

```
Kerminal is an SSH terminal client that works the same way on Windows, macOS,
Linux, Android and iOS. Whether you manage one server or dozens, you open them
as tabs and work from a single window.

■ Many servers, one window
Every connection opens its own tab with its own accent color, so you always know
which server you are typing to. Drag tabs to reorder them, duplicate a session to
the same host, and keep 10,000 lines of scrollback per tab.

■ Credentials stay in the OS vault
Metadata (hostname, port, username) lives in a local database; passwords and
private keys go to Windows Credential Manager (Keychain/Keystore elsewhere).
Nothing is written to a plaintext file.

■ Host key verification
Unknown hosts show their fingerprint and ask for your trust. If a trusted host's
key changes later, Kerminal warns you about a possible man-in-the-middle.

■ Host management
Group hosts, search them, duplicate one to add a similar server quickly, or use
Quick Connect for a one-off session you don't want to save.

■ Encrypted backup
Export all hosts to a passphrase-encrypted .kerminal file and restore it on
another machine.

■ Optional account sync and team sharing
Create an account to sync your host list across devices and share a host or a
whole group with a colleague by invitation. Host data is encrypted on your device
with AES-256-GCM before upload, so the server never sees plaintext. Everything
else works fully offline without an account.

■ Also included
xterm-compatible terminal emulation, a special-key toolbar (Ctrl, Alt, arrows,
Tab, Esc), light/dark themes, adjustable font size, and update notifications.

Questions and bug reports: https://github.com/knoxxr/kerminal/issues
```

### App features

```
Tabbed SSH sessions with per-tab color, drag reordering and session duplication
Password and SSH key authentication, passphrase supported
Credentials stored in the Windows secure vault, separate from metadata
Host key fingerprint verification with change warnings
Host groups and search
Quick Connect for one-off sessions
xterm-compatible terminal with 10,000-line scrollback
Special-key toolbar (Ctrl / Alt / arrows / Tab / Esc)
Passphrase-encrypted backup export and import
Optional account sync with end-to-end encryption (AES-256-GCM)
Share hosts and groups with teammates by invitation
Light and dark themes, adjustable font size
Same experience on Windows, macOS, Linux, Android and iOS
```

### Short description

```
A cross-platform SSH terminal client that connects to many servers in tabs.
Credentials are kept in the Windows secure vault, with host key verification,
encrypted backups and optional end-to-end encrypted sync.
```

### What's new in this version

```
0.4.9
- Fixed tabs being unreachable on phones (only one tab visible, no switching)
- SSH sessions now reconnect automatically after an app switch, keeping scrollback
- Fixed hidden tabs stealing keyboard focus when a connection came up
- Added a 20-second keep-alive so idle links survive NAT and server timeouts
```

### Search terms

```
ssh
ssh client
terminal
remote shell
server admin
putty alternative
terminal emulator
```

---

## 7. 스크린샷 · 이미지 (직접 준비 필요)

| 항목 | 요구사항 | 비고 |
|---|---|---|
| 스크린샷 | **최소 1장**, 권장 4~6장. PNG, 1366×768 이상 | 데스크톱 실행 화면 캡처 |
| 스토어 로고 | 300×300 PNG 권장 | `assets/icon/app_icon.png`(1024²)에서 리사이즈 |
| 패키지 로고 | MSIX에 이미 포함 | 별도 업로드 불필요 |

**추천 스크린샷 구성**
1. 터미널 탭 여러 개가 열린 메인 화면 (색상 구분이 드러나게)
2. 호스트 목록 — 그룹으로 묶인 상태
3. 호스트 추가 화면 — SSH 키 인증 선택
4. 호스트 키 검증 대화상자 (보안 기능 강조)
5. 설정 — 테마/글꼴/백업

> 캡처에 **실제 서버 주소·사용자명·IP가 노출되지 않도록** 더미 값으로 바꾸고 찍으세요.
> 인증 심사에서 개인정보 노출로 반려될 수 있습니다.

---

## 8. 개인정보처리방침 (필수)

전문은 저장소의 **[PRIVACY.md](PRIVACY.md)** 에 있습니다(한국어 + 영어).
코드에서 확인한 실제 데이터 흐름만 기술했으며, 법률 검토는 별도로 받으세요.

**파트너 센터에 넣을 URL** (둘 중 하나):

| 방식 | URL | 비고 |
|---|---|---|
| GitHub 마크다운 (권장·즉시 사용) | `https://github.com/knoxxr/kerminal/blob/main/PRIVACY.md` | 추가 작업 없음. `main`에 푸시하면 바로 유효 |
| GitHub Pages | `https://knoxxr.github.io/kerminal/privacy.html` | **현재 Pages가 활성화돼 있지 않습니다**(API 404). 쓰려면 저장소 설정에서 Pages를 켜고 페이지를 배포해야 함 |

**방침이 반드시 답해야 하는 것** (스토어 정책 10.5.1 — 아래 항목이 빠지면 반려):

1. 어떤 정보를 접근·수집·전송하는가 → §2 (로컬), §5 (계정)
2. 어떻게 사용하는가 → 각 항목의 "목적" 열
3. 어디에 어떻게 보관하고 무엇으로 보호하는가 → OS 보안 저장소 / AES-256-GCM 종단 간 암호화
4. 제3자 제공·처리 위탁 → §6 (Supabase, GitHub)
5. 사용자의 통제권과 삭제 방법 → §7 (앱 제거, 계정 삭제 요청 주소)
6. 연락처 → §10

**주의할 사실 관계** (초안 작성 중 코드 확인으로 바로잡은 부분):

- macOS의 App Store 외 배포 빌드는 키체인이 아니라 **암호화된 로컬 파일**에 시크릿을
  보관합니다(`file_secret_store.dart`). "모든 플랫폼에서 OS 키체인 사용"이라고 쓰면 거짓입니다.
- 공유 초대 시 **초대한 사람의 이메일이 상대에게 노출**됩니다 — 사용자 간 개인정보
  제공이므로 명시했습니다.
- 계정 사용 시 **호스트 편집 이력 스냅샷(암호문)** 이 서버에 누적됩니다.
- 로그인 **세션 토큰이 기기에 저장**됩니다.
- 접속 로그·명령 기록은 로컬에도 저장하지 않습니다(DB 스키마에 해당 테이블 없음).

## 9. 인증 담당자에게 보내는 메모 (Notes for certification)

```
Kerminal is an SSH terminal client. To exercise the main feature the tester needs
a reachable SSH server.

How to test without any account:
1. Launch the app. The host list is empty on first run.
2. Press "+" to add a host, or use Quick Connect (bolt icon) for a one-off session.
3. Enter the address, port, username and password of any SSH server and connect.
   Any public SSH sandbox works; the app does not depend on our infrastructure.
4. On first connection the app shows the server's key fingerprint and asks you to
   trust it. This dialog is expected behavior, not an error.
5. A tab opens with a live shell. Multiple tabs can be opened and reordered.

Account features (sign-in, cloud sync, sharing) are entirely optional. The app is
fully functional without them; no sign-in wall exists anywhere.

Network use: outbound SSH (TCP, user-specified host/port), HTTPS to GitHub for the
update manifest, and HTTPS to Supabase only if the user creates an account.

Restricted capability — runFullTrust: Kerminal is a Flutter/Win32 desktop
application packaged as MSIX. runFullTrust is required for the packaged desktop
runtime itself; the app does not use it to modify the system, install drivers or
services, or touch other applications' data. It writes only to its own storage and
the Windows credential store, and its only outbound traffic is the SSH connections
the user initiates plus the two HTTPS endpoints above.
```

---

## 10. 제출 체크리스트

- [ ] 파트너 센터에서 `Kerminal` 이름 예약
- [ ] 제품 ID 화면에서 `identity_name` / `publisher` / `publisher_display_name` 확인
- [ ] `pubspec.yaml`의 `msix_config` 세 값 교체 (§0-1)
- [ ] `PRIVACY.md`를 `main`에 푸시하고 URL 확인 (§8)
- [ ] 스크린샷 최소 1장 (더미 데이터로) 촬영 (§7)
- [ ] `dart run msix:create --store --version 0.4.9.0 ...` 로 패키지 생성 (§0-2)
- [ ] 가격/시장/속성/연령 등급 입력 (§2~4)
- [ ] 등록 정보 ko-KR + en-US 입력 (§5, §6)
- [ ] 인증 메모 붙여넣기 (§9)
- [ ] 제출
