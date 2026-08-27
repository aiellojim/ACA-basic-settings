-- ACA Basic Settings — new tables (draft, not yet applied)
-- Shared Supabase project (same one AVA basic settings / AVA UI settings / SiteChat Settings use).
-- KMS users are intentionally NOT a new table here — they reuse the existing
-- public.web_portal_users table (email/username/kms_level columns already match 1:1).

-- name/welcome are plain text, not jsonb - Jim confirmed (2026-08-27) the org only fills in one
-- version of each; only the surrounding form chrome (labels/buttons) needs to be trilingual.
create table public.aca_transfer_departments (
  id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  sort_order int not null default 0,
  name text not null default '',
  ext text not null default '',
  emails text not null default '', -- multiple emails, semicolon-separated (matches AVA's convention)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- department_name is free text, NOT a foreign key (Jim, 2026-08-27: the field stays hand-fillable;
-- picking an existing department name is just a convenience autofill, not a hard requirement). The
-- front end treats it as "linked" only when the text exactly matches a current
-- aca_transfer_departments.name for the same project - when linked, ext always mirrors that
-- department's ext (locked in the UI) instead of being independently editable. email is always its
-- own column: pre-filled from the department's notification email when a department match happens,
-- but stays editable per scenario after that.
create table public.aca_transfer_scenarios (
  id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  sort_order int not null default 0,
  name text not null default '',
  handling text not null default 'transfer_human' check (handling in ('transfer_human','auto_ticket')),
  department_name text not null default '',
  ext text not null default '',
  email text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Singleton per project, deliberately separate from AVA basic settings' welcome_messages table
-- (Jim confirmed 2026-08-25 these are not the same content).
create table public.aca_welcome_messages (
  project_id uuid primary key references public.projects(id) on delete cascade,
  welcome text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.aca_transfer_departments enable row level security;
alter table public.aca_transfer_scenarios enable row level security;
alter table public.aca_welcome_messages enable row level security;

-- Standard two-policy pattern from aiello-forms-spec.md section 6 (known temporary/interim pattern, see todo #6).
create policy "anon: edit via link" on public.aca_transfer_departments for all to anon using (true) with check (true);
create policy "staff: full access" on public.aca_transfer_departments for all to authenticated
  using (auth.email() like '%@aiello.ai') with check (auth.email() like '%@aiello.ai');

create policy "anon: edit via link" on public.aca_transfer_scenarios for all to anon using (true) with check (true);
create policy "staff: full access" on public.aca_transfer_scenarios for all to authenticated
  using (auth.email() like '%@aiello.ai') with check (auth.email() like '%@aiello.ai');

create policy "anon: edit via link" on public.aca_welcome_messages for all to anon using (true) with check (true);
create policy "staff: full access" on public.aca_welcome_messages for all to authenticated
  using (auth.email() like '%@aiello.ai') with check (auth.email() like '%@aiello.ai');

-- form-submit-notify Edge Function: add a line to its SOURCE_LABELS map for
-- source = "aca_basic_settings", notify recipient avapjm@aiello.ai (per Jim, 2026-08-25).
-- Not included here since that function lives in a different repo/deploy target - just a reminder.
