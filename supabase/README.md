# Kerminal 클라우드 (Supabase) 설정

클라우드 기능(계정/로그인, 접속 리스트 동기화, 공유, 이력/롤백)은 **선택**입니다.
자격증명을 주지 않고 빌드하면 앱은 기존처럼 **로컬 전용**으로 동작합니다.

## 1. Supabase 프로젝트 만들기
1. https://supabase.com 에서 무료 프로젝트 생성
2. **Project Settings → API** 에서 두 값 확인:
   - `Project URL` (예: `https://xxxx.supabase.co`)
   - `anon` `public` key (publishable, 클라이언트에 넣어도 안전 — 실제 보호는 RLS + E2E 암호화가 담당)

## 2. 스키마 적용
Supabase 대시보드 **SQL Editor**에서 [`schema.sql`](schema.sql) 전체를 붙여넣고 실행합니다.
(테이블·RLS 정책·Realtime 발행 설정까지 포함. 재실행해도 안전합니다.)

> **기존 프로젝트 업그레이드(초대 수신 기능):** 공유가 이제 "초대 → 수신" 방식으로
> 바뀌었습니다. `schema.sql`을 **한 번 더 실행**하면 `host_keys.status` 컬럼과
> 수신자용 RLS 정책이 추가됩니다(기존 공유는 `accepted` 기본값으로 그대로 유지).

## 3. 인증 설정
- **Authentication → Providers → Email** 활성화
- 개발 편의를 위해 초기엔 **Confirm email** 을 꺼도 됩니다(운영 시 켜기 권장)

## 4. 자격증명 주입 (커밋 금지)
`--dart-define`으로 빌드 시 주입합니다. 저장소에는 절대 넣지 않습니다.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

빌드/릴리스 시에도 동일하게 전달합니다. CI에서는 GitHub Actions 시크릿으로 넣습니다
(추후 P1에서 워크플로에 배선 예정).

VS Code를 쓴다면 `.vscode/launch.json`의 `args`에 `--dart-define=...`을 넣어두면 편합니다.

## 보안 모델 요약
- 서버에는 **암호문만** 저장됩니다. 호스트 데이터·비밀·개인키의 평문은 서버에 없습니다.
- 계정마다 X25519 키쌍: 공개키는 `profiles`(공유용, 조회 가능), 개인키는 패스프레이즈로
  봉인해 `account_keys`(본인만 접근)에 저장.
- 호스트마다 콘텐츠키로 암호화하고, 그 키를 소유자·공유 대상 공개키로 각각 봉인해
  `host_keys`에 저장. 행이 있으면 복호화 권한이 있다는 뜻.
- **패스프레이즈를 잃으면 E2E 데이터는 복구할 수 없습니다**(설계상). 가입 시 안내 예정.
