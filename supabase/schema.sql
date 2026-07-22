-- Kerminal cloud schema — Supabase / PostgreSQL.
--
-- Run this in the Supabase SQL Editor (or via the CLI) on a fresh project.
-- It is safe to re-run: objects use IF NOT EXISTS and policies are dropped
-- before being recreated.
--
-- SECURITY MODEL (zero-knowledge, end-to-end encrypted):
--   * Every sensitive value stored here is CIPHERTEXT produced on the client.
--     The server never sees plaintext host data, secrets, or private keys.
--   * Each account has an X25519 key pair. The PUBLIC key lives in `profiles`
--     (readable by other users, so they can be shared with). The PRIVATE key is
--     wrapped with the user's passphrase (PBKDF2 + AES-256-GCM) and stored in
--     `account_keys`, which only its owner can read.
--   * Each host has a random symmetric content key. Host data is encrypted with
--     it (`hosts.ciphertext`). That content key is sealed (crypto_box_seal) to
--     each authorized user's public key, one row per user in `host_keys`.
--     Possessing a `host_keys` row == being able to decrypt the host.
--   * Row-Level Security enforces WHO can see/mutate each row. Encryption
--     enforces WHAT they can read. Both layers are required.

-- =============================================================================
-- profiles — public identity + public key (readable by any authenticated user
-- so colleagues can be found by email and shared with).
-- =============================================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null unique,
  display_name text,
  public_key   text not null,            -- base64 X25519 public key
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- =============================================================================
-- account_keys — the passphrase-wrapped private key. Owner-only. Split from
-- profiles so RLS can hide it (RLS is row-, not column-level).
-- =============================================================================
create table if not exists public.account_keys (
  id                  uuid primary key references auth.users (id) on delete cascade,
  wrapped_private_key text not null,      -- JSON envelope: PBKDF2 + AES-256-GCM
  updated_at          timestamptz not null default now()
);

-- =============================================================================
-- hosts — canonical encrypted host record. Only the owner mutates this row;
-- shared collaborators propose changes via host_versions instead.
-- =============================================================================
create table if not exists public.hosts (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references auth.users (id) on delete cascade,
  ciphertext text not null,              -- AES-256-GCM envelope of host JSON
  version    integer not null default 1, -- app-managed, monotonic per host
  deleted    boolean not null default false,
  updated_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists hosts_owner_idx on public.hosts (owner_id);

-- =============================================================================
-- host_keys — sealed content key per authorized user (owner + each sharee).
-- can_edit lets a sharee propose edits; the owner always can.
-- =============================================================================
create table if not exists public.host_keys (
  host_id            uuid not null references public.hosts (id) on delete cascade,
  recipient_id       uuid not null references auth.users (id) on delete cascade,
  sealed_content_key text not null,      -- crypto_box_seal(content_key, pubkey)
  can_edit           boolean not null default true,
  created_at         timestamptz not null default now(),
  primary key (host_id, recipient_id)
);
create index if not exists host_keys_recipient_idx on public.host_keys (recipient_id);

-- =============================================================================
-- host_versions — append-only change log for history/rollback AND for
-- collaborator edit proposals.
--   status 'applied'  : a committed version of the canonical host
--   status 'proposed' : a sharee's edit awaiting the owner's sync decision
--   status 'rejected' : owner declined the proposal
-- =============================================================================
create table if not exists public.host_versions (
  id         uuid primary key default gen_random_uuid(),
  host_id    uuid not null references public.hosts (id) on delete cascade,
  version    integer not null,           -- app-managed sequence per host
  editor_id  uuid not null references auth.users (id),
  op         text not null check (op in ('create','update','delete','rollback')),
  ciphertext text,                        -- snapshot (null only for a pure delete)
  status     text not null default 'applied'
               check (status in ('applied','proposed','rejected')),
  created_at timestamptz not null default now()
);
create index if not exists host_versions_host_idx
  on public.host_versions (host_id, version);
create index if not exists host_versions_pending_idx
  on public.host_versions (host_id) where status = 'proposed';

-- keep updated_at fresh -------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists hosts_touch on public.hosts;
create trigger hosts_touch before update on public.hosts
  for each row execute function public.touch_updated_at();

-- helper: is the current user allowed to see this host? ------------------------
create or replace function public.can_access_host(h uuid) returns boolean as $$
  select exists (
    select 1 from public.hosts x
    where x.id = h and x.owner_id = auth.uid()
  ) or exists (
    select 1 from public.host_keys k
    where k.host_id = h and k.recipient_id = auth.uid()
  );
$$ language sql security definer stable;

create or replace function public.is_host_owner(h uuid) returns boolean as $$
  select exists (
    select 1 from public.hosts x where x.id = h and x.owner_id = auth.uid()
  );
$$ language sql security definer stable;

create or replace function public.can_edit_host(h uuid) returns boolean as $$
  select public.is_host_owner(h) or exists (
    select 1 from public.host_keys k
    where k.host_id = h and k.recipient_id = auth.uid() and k.can_edit
  );
$$ language sql security definer stable;

-- =============================================================================
-- Row-Level Security
-- =============================================================================
alter table public.profiles      enable row level security;
alter table public.account_keys  enable row level security;
alter table public.hosts         enable row level security;
alter table public.host_keys     enable row level security;
alter table public.host_versions enable row level security;

-- profiles: anyone signed in can look others up (share by email); write self only
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);
drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles
  for insert to authenticated with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- account_keys: strictly owner-only
drop policy if exists account_keys_all on public.account_keys;
create policy account_keys_all on public.account_keys
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- hosts: readable by owner or any sharee; mutable by owner only
drop policy if exists hosts_select on public.hosts;
create policy hosts_select on public.hosts
  for select to authenticated using (public.can_access_host(id));
drop policy if exists hosts_insert on public.hosts;
create policy hosts_insert on public.hosts
  for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists hosts_update on public.hosts;
create policy hosts_update on public.hosts
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists hosts_delete on public.hosts;
create policy hosts_delete on public.hosts
  for delete to authenticated using (owner_id = auth.uid());

-- host_keys: readable by the recipient or the host owner; managed by owner only
drop policy if exists host_keys_select on public.host_keys;
create policy host_keys_select on public.host_keys
  for select to authenticated
  using (recipient_id = auth.uid() or public.is_host_owner(host_id));
drop policy if exists host_keys_write on public.host_keys;
create policy host_keys_write on public.host_keys
  for all to authenticated
  using (public.is_host_owner(host_id))
  with check (public.is_host_owner(host_id));

-- host_versions:
--   SELECT  — anyone who can access the host
--   INSERT  — owner may write any status; a sharee may write only 'proposed'
--   UPDATE  — owner only (accept/reject a proposal)
drop policy if exists host_versions_select on public.host_versions;
create policy host_versions_select on public.host_versions
  for select to authenticated using (public.can_access_host(host_id));
drop policy if exists host_versions_insert on public.host_versions;
create policy host_versions_insert on public.host_versions
  for insert to authenticated with check (
    editor_id = auth.uid() and (
      public.is_host_owner(host_id)
      or (public.can_edit_host(host_id) and status = 'proposed')
    )
  );
drop policy if exists host_versions_update on public.host_versions;
create policy host_versions_update on public.host_versions
  for update to authenticated
  using (public.is_host_owner(host_id))
  with check (public.is_host_owner(host_id));

-- =============================================================================
-- Realtime — let clients subscribe to changes (edit notifications, sync).
-- Idempotent: only add a table to the publication if it isn't already there.
-- =============================================================================
do $$
declare t text;
begin
  foreach t in array array['hosts','host_keys','host_versions'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
