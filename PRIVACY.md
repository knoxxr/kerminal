# Kerminal 개인정보처리방침 / Privacy Policy

**최종 수정일 / Last updated: 2026-08-02**
**제공자 / Provider: Minary** · 문의 / Contact: kbkim@smic.kr

---

## 한국어

### 1. 요약

Kerminal은 **로컬 우선(local-first)** SSH 터미널 클라이언트입니다.
계정을 만들지 않으면 사용자의 어떤 정보도 Minary의 서버로 전송되지 않으며,
계정 기능은 전적으로 선택 사항입니다. 광고·행동 분석·크래시 수집 도구를 포함하지 않습니다.

### 2. 기기에만 저장되는 정보

다음 정보는 사용자의 기기에만 저장되며 Minary는 접근할 수 없습니다.

| 정보 | 저장 위치 |
|---|---|
| 호스트 메타데이터 (이름, 주소, 포트, 사용자명, 그룹, 인증 방식) | 앱 내부의 로컬 데이터베이스 |
| SSH 비밀번호 · 개인키 · 패스프레이즈 | 운영체제가 제공하는 보안 저장소 |
| 신뢰한 호스트 키 지문(known hosts) | 앱 로컬 설정 저장소 |
| 앱 설정 (테마, 글꼴 크기) | 앱 로컬 설정 저장소 |
| 로그인 세션 토큰 (계정 사용 시) | 앱 로컬 저장소 |

- 비밀번호와 개인키는 **평문 데이터베이스에 기록되지 않으며**, 메타데이터와 분리해
  보관하고 식별자로만 연결합니다.
- 보안 저장소는 플랫폼별로 Windows 자격 증명 저장소, iOS·iPadOS 키체인,
  Android 키스토어, Linux Secret Service(키링)를 사용합니다.
  **예외:** App Store를 거치지 않고 배포되는 macOS 빌드는 키체인 접근이 제한되므로
  기기 내 **암호화된 파일**에 보관합니다.
- Kerminal은 접속 기록(접속 시각·명령어 이력)을 별도로 저장하지 않습니다.

### 3. SSH 연결

SSH 연결은 사용자가 지정한 서버로 **직접** 이루어집니다. Minary의 서버를 경유하지 않으며,
터미널에 입력한 명령이나 서버가 출력한 내용은 수집·전송·저장되지 않습니다.

### 4. 업데이트 확인

새 버전 확인을 위해 GitHub에 공개된 버전 매니페스트
(`https://github.com/knoxxr/kerminal/releases/latest/download/latest.json`)를 HTTPS로 요청합니다.
이 요청에는 개인 식별 정보가 포함되지 않으며, 요청 과정에서 발생하는 IP 주소 등의
접속 정보는 GitHub가 자체 방침에 따라 처리합니다.

### 5. 계정 기능 (선택) — 수집하는 개인정보

계정을 만들 때에만 아래 정보가 Minary가 운영하는 클라우드(인프라: Supabase)에 저장됩니다.

| 항목 | 목적 | 보관 |
|---|---|---|
| 이메일 주소 | 계정 식별, 로그인, 공유 대상 지정 | 계정 삭제 시까지 |
| 표시 이름(선택 입력) | 공유 시 상대에게 표시 | 계정 삭제 시까지 |
| 공개키(X25519) | 공유 대상에게 암호화 키를 전달 | 계정 삭제 시까지 |
| 암호로 감싼 개인키 | 다른 기기에서 복호화 (PBKDF2 + AES-256-GCM) | 계정 삭제 시까지 |
| 동기화·공유 대상 호스트 정보 | 기기 간 동기화, 동료 공유 | 삭제 시까지 |
| 호스트 편집 이력 스냅샷 | 변경 이력 조회 및 되돌리기 | 호스트 삭제 시까지 |

**호스트 정보는 기기에서 AES-256-GCM으로 암호화된 뒤 업로드됩니다.**
암호화 키는 사용자의 계정 암호에서 파생되며 서버로 전송되지 않으므로,
Minary와 인프라 제공자는 호스트 주소·사용자명·비밀번호·개인키를 열람할 수 없습니다.
서버에는 암호문과 위 표의 계정 정보만 남습니다.

**공유 시 알아두실 점:** 동료를 초대하려면 상대의 이메일 주소를 입력해야 하며,
초대를 받은 사람에게는 **초대한 사람의 이메일 주소**가 표시됩니다.
공유를 수락한 상대는 해당 호스트의 정보(접속 계정과 비밀번호·키 포함)를 복호화할 수
있으므로, 신뢰하는 상대에게만 공유하십시오.

### 6. 제3자 제공 및 처리 위탁

- 개인정보를 판매하거나 광고 목적으로 제공하지 않습니다.
- 계정·클라우드 저장 기능의 인프라는 **Supabase**를 이용합니다(처리 위탁).
- 업데이트 매니페스트와 설치 파일은 **GitHub**에서 배포합니다.
- 법령에 따른 적법한 요청이 있는 경우에 한해 보유 중인 정보를 제공할 수 있으나,
  암호화된 호스트 정보는 Minary도 복호화할 수 없습니다.

### 7. 보관 기간과 삭제

- **로컬 데이터:** 앱을 제거하면 삭제됩니다(보안 저장소에 저장된 비밀 포함).
  앱 내에서 호스트를 개별 삭제할 수도 있습니다.
- **계정 데이터:** 계정 삭제를 원하시면 kbkim@smic.kr 로 요청해 주십시오.
  본인 확인 후 계정과 연결된 프로필·키·호스트 암호문·이력을 모두 삭제합니다.
- 열람·정정·삭제·처리정지 요구는 같은 주소로 접수합니다.

### 8. 아동의 개인정보

Kerminal은 서버 관리자를 위한 개발자 도구로, 아동을 대상으로 하지 않으며
아동의 개인정보를 의도적으로 수집하지 않습니다.

### 9. 방침 변경

내용이 변경되면 이 문서와 최종 수정일을 갱신하고, 중요한 변경은 릴리스 노트로
알립니다.

### 10. 문의

Minary · kbkim@smic.kr · https://github.com/knoxxr/kerminal/issues

---

## English

### 1. Summary

Kerminal is a **local-first** SSH terminal client. If you do not create an account,
none of your data is sent to Minary. Account features are entirely optional.
The app contains no advertising, analytics, or crash-reporting SDKs.

### 2. Data stored only on your device

| Data | Where |
|---|---|
| Host metadata (label, address, port, username, group, auth method) | Local database in the app |
| SSH passwords, private keys, passphrases | Operating-system secure storage |
| Trusted host key fingerprints (known hosts) | Local app settings |
| App settings (theme, font size) | Local app settings |
| Sign-in session token (if you use an account) | Local app storage |

Secrets are never written to the plaintext database; they are kept separately and
referenced by an opaque identifier. Secure storage means Windows Credential
Storage, iOS/iPadOS Keychain, Android Keystore, or the Linux Secret Service.
**Exception:** macOS builds distributed outside the App Store cannot use the
Keychain, so secrets are kept in an encrypted file on the device instead.
Kerminal does not keep a log of your connections or commands.

### 3. SSH connections

Connections are made **directly** to the server you specify. They are not proxied
through Minary, and terminal input/output is never collected, transmitted, or stored.

### 4. Update check

The app fetches a public version manifest over HTTPS from GitHub
(`https://github.com/knoxxr/kerminal/releases/latest/download/latest.json`).
No personal data is included; connection data such as your IP address is handled
by GitHub under its own policy.

### 5. Account features (optional) — personal data we collect

Only if you create an account, the following is stored in our cloud
(infrastructure: Supabase):

- Email address — account identity, sign-in, and choosing who to share with
- Display name (optional)
- X25519 public key — used to deliver encryption keys to share recipients
- Password-wrapped private key (PBKDF2 + AES-256-GCM)
- Synced/shared host records and their edit-history snapshots

**Host records are encrypted on your device with AES-256-GCM before upload.**
The encryption key is derived from your account password and never sent to the
server, so neither Minary nor its infrastructure provider can read host addresses,
usernames, passwords, or private keys — only ciphertext is stored.

**About sharing:** to invite a colleague you enter their email address, and the
invitee sees the **inviter's email address**. Anyone who accepts a share can
decrypt that host's credentials, so share only with people you trust.

### 6. Third parties

We do not sell personal data or share it for advertising. Supabase provides the
account and storage infrastructure; GitHub hosts the update manifest and installers.
We disclose data only when legally required — and encrypted host data cannot be
decrypted by us.

### 7. Retention and deletion

Local data is removed when you uninstall the app, including secrets in the OS
secure storage. To delete your account and all associated cloud data (profile,
keys, host ciphertext, history), email kbkim@smic.kr. Requests to access, correct,
or restrict processing go to the same address.

### 8. Children

Kerminal is a developer tool for server administrators. It is not directed at
children and we do not knowingly collect data from them.

### 9. Changes

Material changes are reflected here with an updated date and announced in the
release notes.

### 10. Contact

Minary · kbkim@smic.kr · https://github.com/knoxxr/kerminal/issues
