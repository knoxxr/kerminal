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
- **서명(현재):** 자체 서명 코드사이닝 인증서(`CN=SMIC`)로 CI에서 서명합니다.
  개인키(`.pfx`)는 GitHub Actions 시크릿 `WINDOWS_CERT_BASE64`/`WINDOWS_CERT_PASSWORD`,
  공개 인증서는 `windows/kerminal-codesign.cer`(릴리스에 동봉).
  - **최종 사용자 설치 (최초 1회):** 자체 서명 인증서는 스스로가 루트이므로
    **"신뢰할 수 있는 루트 인증 기관"**에 넣어야 `0x800B010A`가 사라집니다.
    관리자 PowerShell에서:
    ```powershell
    Import-Certificate -FilePath .\kerminal-codesign.cer -CertStoreLocation Cert:\LocalMachine\Root
    ```
    그런 다음 `kerminal.msix` 실행 → 게시자가 "SMIC"로 확인되어 설치됩니다.
    (GUI로는 .cer 우클릭 → 인증서 설치 → 로컬 컴퓨터 → "신뢰할 수 있는 루트 인증 기관".)
- **정식 서명/스토어:** 상용 Authenticode(OV/EV) 인증서로 교체하거나 Microsoft Store
  제출(`dart run msix:create --store`, 파트너 센터 계정) 시 경고 없이 설치됩니다.

## macOS (DMG)
빌드 환경: macOS + Xcode.
```bash
flutter build macos --release
# DMG 생성 (create-dmg 또는 flutter_distributor)
flutter_distributor release --name macos --jobs macos-dmg
```
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
- CI에서는 `key.properties`와 `.jks`를 시크릿에서 생성해 주입합니다.

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

**매니페스트 URL 지정** (빌드 시 `--dart-define`):
```bash
flutter build windows --dart-define=UPDATE_MANIFEST_URL=https://example.com/kerminal/latest.json
```
URL이 비어 있으면 업데이트 체크는 비활성(아무것도 표시 안 함)입니다.

**`latest.json` 형식** (정적 호스트/GitHub Releases 자산 등):
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
