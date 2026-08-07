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

## 5. 문의 기능 (Edge Function)

앱 **설정 → Support → Contact us** 에서 보낸 문의를 메일로 전달합니다.
**수신 주소는 이 저장소와 앱 어디에도 없습니다** — 함수의 서버 시크릿에만 둡니다.
저장소가 공개이고 앱은 사용자에게 배포되므로, `mailto:` 링크나 앱 내 상수로 두면
주소가 그대로 노출됩니다.

1. 스키마 재적용 (`feedback` 테이블 생성 — `schema.sql`을 다시 실행하면 됩니다)
2. 메일 발송용 [Resend](https://resend.com) API 키 발급 (무료 티어로 충분)
3. 함수 배포와 시크릿 설정:

```bash
supabase link --project-ref <your-project-ref>
supabase functions deploy send-feedback

supabase secrets set \
  FEEDBACK_TO='받는사람@example.com' \
  RESEND_API_KEY='re_...' \
  FEEDBACK_FROM='Kerminal <onboarding@resend.dev>'
```

- `FEEDBACK_TO` — 문의를 받을 주소. **이 값만 바꾸면 수신자가 바뀝니다.**
- `FEEDBACK_FROM` — 보내는 주소.

  > ⚠️ **기본값 `onboarding@resend.dev`는 테스트 전용입니다.** Resend는 이 도메인에서
  > **Resend 계정에 등록된 본인 이메일로만** 발송을 허용하고, 다른 주소로 보내면
  > **403**으로 거부합니다. 즉 `FEEDBACK_TO`가 Resend 가입 주소와 다르면 문의 메일이
  > 한 통도 오지 않습니다(앱에는 "접수됨"으로 표시되고 내용은 `feedback` 테이블에
  > 남습니다).
  >
  > 해결: ① Resend 계정 이메일을 `FEEDBACK_TO`와 같게 맞추거나,
  > ② [resend.com/domains](https://resend.com/domains)에서 보유 도메인을 인증하고
  > `FEEDBACK_FROM`을 그 도메인 주소로 바꾸세요(권장 — 스팸 처리도 줄어듭니다).
  >
  > 발송 실패는 **Edge Functions → send-feedback → Logs** 에 사유가 찍힙니다.
- 함수는 `verify_jwt = false`(`config.toml`)라 **로그인하지 않은 사용자도** 문의할 수
  있습니다. 익명 스팸을 막기 위해 길이 제한(메시지 5,000자)과 최소 길이 검증이
  들어 있습니다.

> **`feedback` 테이블이 없으면** 앱에 "Could not send your message (could not
> store your message)"가 뜹니다. 1단계(스키마 적용)를 건너뛰면 이 상태가 됩니다 —
> `schema.sql`을 다시 실행하세요.

> **서비스 키 이름 주의:** 함수는 RLS를 우회하는 키가 필요합니다. 레거시 JWT 키를
> 쓰는 프로젝트는 `SUPABASE_SERVICE_ROLE_KEY`(문자열), publishable/secret 키로
> 옮긴 프로젝트는 `SUPABASE_SECRET_KEYS`(JSON)를 받습니다. 함수는 **양쪽 다**
> 읽으며, 둘 다 없으면 로그에 그 사실을 남기고 500으로 응답합니다(예전에는 인증 없이
> 삽입을 시도해 RLS에 막히고, 원인이 드러나지 않았습니다). 이 값들은 Supabase가
> 자동 주입하므로 직접 설정하지 않습니다.

모든 문의는 `public.feedback` 테이블에도 저장됩니다. 메일 발송이 실패해도 내용이
남으므로, 대시보드 **Table Editor → feedback** 에서 확인할 수 있습니다.
이 테이블은 RLS가 켜져 있고 **정책이 없어** 클라이언트에서는 읽기·쓰기가 모두
불가능합니다(함수가 service-role 키로만 기록).

문의에는 메시지·(선택)회신 주소·플랫폼·앱 버전만 담깁니다. 호스트 목록·자격증명·
터미널 출력은 전송되지 않습니다.

## 보안 모델 요약
- 서버에는 **암호문만** 저장됩니다. 호스트 데이터·비밀·개인키의 평문은 서버에 없습니다.
- 계정마다 X25519 키쌍: 공개키는 `profiles`(공유용, 조회 가능), 개인키는 패스프레이즈로
  봉인해 `account_keys`(본인만 접근)에 저장.
- 호스트마다 콘텐츠키로 암호화하고, 그 키를 소유자·공유 대상 공개키로 각각 봉인해
  `host_keys`에 저장. 행이 있으면 복호화 권한이 있다는 뜻.
- **패스프레이즈를 잃으면 E2E 데이터는 복구할 수 없습니다**(설계상). 가입 시 안내 예정.
