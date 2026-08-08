# 배포 가이드 (Deployment)

Kerminal은 Flutter 단일 코드베이스로 6개 타깃(Windows/macOS/Linux/iOS/Android/Web)을
배포합니다. 이 문서는 릴리스 아티팩트 빌드와 서명/스토어 제출 절차를 정리합니다.

> **자동화:** 태그를 밀면 GitHub Actions([release.yml](.github/workflows/release.yml))가
> 전 플랫폼 아티팩트를 빌드해 **드래프트 릴리스**에 첨부합니다.
> ```bash
> git tag v0.1.0 && git push origin v0.1.0
> ```
> 서명/스토어 제출은 아래 플랫폼별 절차에 따라 인증서·계정이 필요합니다.

## 버전 올리기
`pubspec.yaml`의 `version: 0.1.0+1` (= `버전+빌드번호`)을 수정하고
[CHANGELOG.md](CHANGELOG.md)에 항목을 추가한 뒤 태그를 만듭니다.

## 아이콘
소스: `assets/icon/app_icon.png` (1024×1024). 변경 후 재생성:
```bash
dart run flutter_launcher_icons
```

---

## Windows (MSIX)

> **Windows는 두 경로로 배포합니다.**
> 태그 릴리스(`release.yml`)가 자체 서명 `.msix` + `.cer`을 첨부하고,
> Microsoft Store에도 별도 패키지를 제출합니다.
>
> | 용도 | 워크플로 | 산출물 |
> |---|---|---|
> | 태그 릴리스 (직접 배포) | `release.yml` | 자체 서명(`CN=Minary`) `.msix` + `.cer`, 버전 `X.Y.Z.B` |
> | 스토어 제출 | **Store package (MSIX)** (`store-package.yml`) | 서명 없음, 파트너 센터 identity, 버전 `X.Y.Z.0` |
> | 태그 없이 임의 브랜치 빌드 | **Windows sideload (MSIX)** (`windows-sideload.yml`) | 릴리스와 동일한 서명, 아티팩트로만 |
>
> 스토어와 GitHub 배포본은 **패키지 신원이 서로 다릅니다**(게시자·identity). 한쪽에서
> 설치한 앱을 다른 쪽 패키지로 업데이트할 수 없으니, 사용자는 한 경로를 유지해야 합니다.
> 스토어 제출 절차는 [STORE_SUBMISSION.md](STORE_SUBMISSION.md) 참고.

빌드 환경: Windows + Visual Studio Build Tools + **C++ ATL 컴포넌트**.
```powershell
# ATL 설치 (최초 1회, 관리자)
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify `
  --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community" `
  --add Microsoft.VisualStudio.Component.VC.ATL --quiet --norestart

flutter build windows --release
dart run msix:create        # → build/windows/x64/runner/Release/*.msix
```
> **ATL 툴셋 주의:** `flutter_secure_storage`는 `atlstr.h`(ATL)를 요구합니다.
> ATL이 최신 MSVC 툴셋(예: 14.44)에만 설치되고 v143 기본 툴셋이 구버전(예: 14.43)을
> 가리키면 `error C1083: 'atlstr.h'`가 납니다. 빌드 셸에서 ATL 포함 툴셋을 지정하세요:
> ```powershell
> $env:VCToolsVersion = "14.44.35207"   # ATL이 설치된 툴셋 버전
> flutter clean; flutter run -d windows
> ```
> 설치된 툴셋은 `…\BuildTools\VC\Tools\MSVC\`에서, ATL 유무는 각 폴더의
> `atlmfc\include\atlstr.h` 존재로 확인합니다.
- **서명(현재):** 자체 서명 코드사이닝 인증서(`CN=Minary`, RSA-2048/SHA-256, 2036년까지)로
  CI에서 서명합니다.
  개인키(`.pfx`)는 GitHub Actions 시크릿 `WINDOWS_CERT_BASE64`/`WINDOWS_CERT_PASSWORD`,
  공개 인증서는 `windows/kerminal-codesign.cer`(릴리스에 동봉).
  - **최종 사용자 설치 (최초 1회):** 자체 서명 인증서는 스스로가 루트이므로
    **"신뢰할 수 있는 루트 인증 기관"**에 넣어야 `0x800B010A`가 사라집니다.
    관리자 PowerShell에서:
    ```powershell
    Import-Certificate -FilePath .\kerminal-codesign.cer -CertStoreLocation Cert:\LocalMachine\Root
    ```
    그런 다음 `kerminal.msix` 실행 → 게시자가 "Minary"로 확인되어 설치됩니다.
    (GUI로는 .cer 우클릭 → 인증서 설치 → 로컬 컴퓨터 → "신뢰할 수 있는 루트 인증 기관".)
- **정식 서명/스토어:** 상용 Authenticode(OV/EV) 인증서로 교체하거나 Microsoft Store
  제출(`dart run msix:create --store`, 파트너 센터 계정) 시 경고 없이 설치됩니다.
  - 태그 릴리스에 붙는 `kerminal.msix`는 **직접 배포 전용**입니다. 스토어는 이 패키지의
    identity·게시자·버전(4번째 자리)을 모두 거부하므로, 제출본은 Actions의
    **Store package (MSIX)** 워크플로(`.github/workflows/store-package.yml`)로 따로
    만드세요. 입력값과 제출 절차는 [STORE_SUBMISSION.md](STORE_SUBMISSION.md) 참고.
- **인증서 교체 기록 (2026-08-04):** 게시자 표기를 브랜드에 맞추기 위해 코드사이닝
  인증서를 `CN=SMIC` → `CN=Minary`로 재발급했습니다. 시크릿
  `WINDOWS_CERT_BASE64`/`WINDOWS_CERT_PASSWORD`와 `windows/kerminal-codesign.cer`,
  `pubspec.yaml`의 `msix_config.publisher`를 함께 갱신했습니다.
  세 값은 **정확히 일치해야** 하며(어긋나면 `msix:create`가 서명 단계에서 실패),
  이후 인증서를 또 바꿀 때도 셋을 같이 고쳐야 합니다.

  > **주의:** 게시자가 바뀌면 MSIX 패키지 신원(identity)이 달라져 **`CN=SMIC`으로
  > 서명된 기존 설치본은 in-place 업데이트가 불가능**합니다(제거 후 재설치 +
  > 새 `.cer` 신뢰 필요). 영향 범위는 v0.4.8 이하의 `.msix`를 직접 설치한
  > 사용자로 한정됩니다.
  > 이전 `CN=SMIC` 개인키는 시크릿 덮어쓰기로 폐기되었습니다.

## macOS (DMG)
빌드 환경: macOS + Xcode.
```bash
flutter build macos --release
```
릴리스 CI는 추가 의존성 없이 `hdiutil`로 DMG를 만듭니다(`release.yml`의 macos 단계):
앱과 `/Applications` 심볼릭 링크를 담은 폴더를 압축 이미지로 굽습니다.

> **왜 zip이 아니라 DMG인가:** zip은 `.app`을 내려받은 자리에 풀어놓을 뿐이라, 기존
> 설치를 **교체할 방법이 드러나지 않습니다** — 사용자는 다운로드 폴더와
> `/Applications`에 복사본을 각각 갖게 됩니다. 번들 ID가 같아 데이터는 공유되지만
> 어느 것이 최신인지 알 수 없습니다. DMG의 `/Applications` 링크는 드래그하면
> "바꾸기"를 묻는 익숙한 흐름을 만듭니다.
- **App Sandbox 비활성화(중요):** `macos/Runner/*.entitlements`에서 샌드박스를
  꺼둔 상태입니다. 이는 Apple 팀 서명 없이 ad-hoc 서명으로 직접 배포할 때
  `flutter_secure_storage`의 키체인 접근(-34018 `errSecMissingEntitlement` 방지)과
  dartssh2의 아웃바운드 접속을 허용하기 위함입니다. App Store에 올리려면 샌드박스를
  다시 켜고 `keychain-access-groups`(팀 프리픽스 필요) + `network.client`를 추가해야
  합니다.
- **서명/공증:** Apple Developer 계정($99/년), Developer ID 인증서로 codesign 후
  `xcrun notarytool`로 공증(notarize) + `stapler`.
- **App Store:** Xcode Organizer 또는 `xcrun altool`로 업로드.

## Linux (deb / AppImage)
빌드 환경: Linux + `ninja-build libgtk-3-dev`.
```bash
flutter build linux --release
dart pub global activate flutter_distributor
flutter_distributor release --name linux --jobs linux-deb
flutter_distributor release --name linux --jobs linux-appimage
```

## Android (APK / AAB)

> **포그라운드 서비스 선언 주의 (Play Store 제출 시):**
> 앱 전환 중에도 SSH 세션을 유지하려고 `SessionKeepAliveService`가
> `foregroundServiceType="specialUse"`로 선언돼 있습니다(`AndroidManifest.xml`).
> `dataSync`를 쓰지 않는 이유는 **안드로이드 15+에서 dataSync가 하루 6시간으로
> 제한**되어 장시간 셸이 조용히 끊기기 때문입니다.
> Play Store에 올릴 때는 `specialUse` 사용 사유를 콘솔에서 심사받아야 하며,
> 매니페스트의 `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 문구를 그대로 제출하면 됩니다.
> 심사에서 거부되면 `dataSync`로 바꿀 수 있으나 위 6시간 제한을 받습니다.
> (GitHub APK 직접 배포에는 아무 제약이 없습니다.)

빌드 환경: Android SDK(+cmdline-tools) + JDK 17.
1. 릴리스 키스토어 생성:
   ```bash
   keytool -genkey -v -keystore kerminal-release.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias kerminal
   ```
2. `android/key.properties.example`를 `android/key.properties`로 복사해 채웁니다
   (키스토어·비밀번호는 **커밋 금지**, gitignore됨).
3. 빌드:
   ```bash
   flutter build appbundle --release   # Play Store 업로드용 .aab
   flutter build apk --release         # 직접 배포용 .apk
   ```
- **스토어:** Google Play Console 계정($25 1회), Play App Signing 권장.
- **릴리스 서명 (필수):** 릴리스 CI가 시크릿에서 `key.properties`와 키스토어를 만들어
  주입합니다. 시크릿이 없으면 워크플로가 **의도적으로 실패**합니다 — 디버그 서명본이
  릴리스로 나가는 것을 막기 위함입니다.

  | 시크릿 | 내용 |
  |---|---|
  | `ANDROID_KEYSTORE_BASE64` | PKCS#12 키스토어(base64) |
  | `ANDROID_KEYSTORE_PASSWORD` | 키스토어·키 비밀번호(PKCS#12는 동일) |
  | `ANDROID_KEY_ALIAS` | 키 별칭 (`kerminal`) |

  > ⚠️ **이 키를 잃으면 안 됩니다.** 안드로이드는 서명이 다른 APK로 덮어쓰기를
  > 막으므로(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), 키가 바뀌면 모든 사용자가
  > **앱을 제거하고 재설치**해야 하고 저장된 호스트를 잃습니다. Play Store에서는
  > 업데이트 자체가 거부됩니다. 키스토어 파일과 비밀번호를 안전한 곳에 백업하세요.

  > **2026-08-06 이전 릴리스 주의:** 그때까지의 APK는 시크릿이 없어 **디버그 키**로
  > 서명됐고, 그 키는 빌드마다 달랐습니다. 그래서 구버전 위에 신버전을 설치할 수
  > 없었습니다. 이번 릴리스 키로 전환하면서 **한 번은 제거 후 재설치**가 필요하며,
  > 이후 업데이트는 정상 동작합니다.

## iOS (App Store)
빌드 환경: macOS + Xcode + Apple Developer 계정.
```bash
flutter build ipa --release
```
- 서명(Automatic/Manual), `xcrun altool`/Transporter로 App Store Connect 업로드.

## Web
```bash
flutter build web --release   # → build/web (정적 호스팅)
```
- 정적 호스트(Netlify/Firebase Hosting/S3 등)에 업로드.
- **주의:** 브라우저는 raw TCP를 열 수 없어 웹 빌드에서는 직접 SSH 접속이
  동작하지 않습니다. 웹은 UI 데모/관리 용도이며, 실제 SSH는 데스크톱/모바일에서
  동작합니다. (원한다면 WebSocket↔SSH 프록시 백엔드가 별도로 필요합니다.)

---

## 자동 업데이트 (버전 인식 + 다운로드 안내)
앱은 원격 **버전 매니페스트(`latest.json`)**를 받아 현재 버전과 semver 비교 후,
새 버전이 있으면 설정 화면과 호스트 목록(설정 아이콘 배지)에 알리고 플랫폼별
다운로드 링크를 엽니다.

**매니페스트 URL**: 기본값으로 GitHub "최신 릴리스" 자산
(`.../releases/latest/download/latest.json`)이 코드에 내장돼 있어, 별도 설정
없이 동작합니다. 다른 곳을 쓰려면 빌드 시 `--dart-define=UPDATE_MANIFEST_URL=...`
로 덮어쓰고, 빈 값으로 두면 체크가 비활성화됩니다.

**`latest.json` 자동 생성**: 릴리스 워크플로가 매 릴리스마다 아래 형식으로
`latest.json`을 만들어 릴리스에 첨부합니다(수동 관리 불필요). 형식:
```json
{
  "version": "0.2.0",
  "notes": "변경 사항 요약",
  "downloads": {
    "windows": "https://example.com/kerminal-0.2.0.msix",
    "macos":   "https://example.com/kerminal-0.2.0.dmg",
    "linux":   "https://example.com/kerminal-0.2.0.AppImage",
    "android": "https://example.com/kerminal-0.2.0.apk"
  }
}
```
릴리스마다 `pubspec.yaml` 버전을 올리고 이 매니페스트를 갱신하면, 구버전 앱이
자동으로 새 버전을 인식합니다. (인앱 자동 설치는 스토어/서명 정책상 링크 안내
방식이며, Windows는 MSIX Store 자동 업데이트로 확장 가능.)

## 릴리스 체크리스트
- [ ] `pubspec.yaml` 버전/빌드번호 상향
- [ ] `CHANGELOG.md` 갱신
- [ ] `flutter analyze` / `flutter test` 통과
- [ ] 태그 푸시 → CI 아티팩트 확인
- [ ] 플랫폼별 서명·스토어 제출
