# 배포 가이드 (Deployment)

Kominal은 Flutter 단일 코드베이스로 6개 타깃(Windows/macOS/Linux/iOS/Android/Web)을
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
- **서명/스토어:** `pubspec.yaml`의 `msix_config`에 `publisher`(인증서 CN)와
  인증서를 지정하거나, Microsoft Store 제출 시 `dart run msix:create --store`.
  파트너 센터 계정 필요.

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
   keytool -genkey -v -keystore kominal-release.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias kominal
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

## 자동 업데이트 (데스크톱)
현재 미구현. 후보:
- Windows: MSIX + Microsoft Store 자동 업데이트, 또는 App Installer(.appinstaller).
- 크로스플랫폼: 정적 `latest.json`(버전/URL) 폴링 후 인앱 알림 → 다운로드 유도.
MVP 범위 밖이며 별도 설계 단계에서 채택합니다.

## 릴리스 체크리스트
- [ ] `pubspec.yaml` 버전/빌드번호 상향
- [ ] `CHANGELOG.md` 갱신
- [ ] `flutter analyze` / `flutter test` 통과
- [ ] 태그 푸시 → CI 아티팩트 확인
- [ ] 플랫폼별 서명·스토어 제출
