-- AdVora production backend foundation
-- Apply only to a new Supabase project after review. This migration does not alter the live demo.
-- All balance-changing writes must be performed by trusted server/Edge Function code.
-- Never expose the service-role key in the browser or repository.

create extension if not exists pgcrypto;

create type public.ledger_kind as enum (
  'package_payment', 'video_reward', 'referral_commission',
  'activity_bonus', 'withdrawal_hold', 'withdrawal_release',
  'withdrawal_paid', 'refund', 'admin_adjustment'
);

create type public.payment_state as enum (
  'created', 'pending', 'succeeded', 'failed', 'refunded', 'cancelled'
);

create type public.withdrawal_state as enum (
  'requested', 'under_review', 'approved', 'rejected', 'paid', 'cancelled'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  referral_code text not null unique default encode(gen_random_bytes(8), 'hex'),
  referred_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  constraint no_self_referral check (referred_by is null or referred_by <> id)
);

create table public.packages (
  id text primary key,
  price_micro_usdt bigint not null check (price_micro_usdt >= 0),
  daily_video_limit integer not null check (daily_video_limit >= 0),
  active boolean not null default false
);

-- Initial package values are intentionally inactive until the business model,
-- legal terms, currency and provider flow are approved.
insert into public.packages (id, price_micro_usdt, daily_video_limit, active) values
  ('starter', 0, 3, false),
  ('basic', 0, 6, false),
  ('plus', 0, 10, false),
  ('premium', 0, 15, false)
on conflict (id) do nothing;

create table public.payment_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  package_id text references public.packages(id),
  provider text not null,
  network text not null default 'BEP20' check (network = 'BEP20'),
  chain_id integer not null default 56 check (chain_id = 56),
  provider_reference text,
  amount_micro_usdt bigint not null check (amount_micro_usdt > 0),
  state public.payment_state not null default 'created',
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_reference)
);

create table public.package_activations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  package_id text not null references public.packages(id),
  payment_order_id uuid unique references public.payment_orders(id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.daily_video_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  activation_id uuid not null references public.package_activations(id),
  claim_date date not null,
  claim_number integer not null check (claim_number >= 1),
  reward_micro_usdt bigint not null check (reward_micro_usdt >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, claim_date, claim_number)
);
create index daily_video_claims_user_date_idx
  on public.daily_video_claims(user_id, claim_date);

-- Immutable accounting ledger: amounts are integer micro-USDT units (1 USDT = 1,000,000 units), never floats.
-- Positive amounts credit a user; negative amounts debit/hold funds.
create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  kind public.ledger_kind not null,
  amount_micro_usdt bigint not null check (amount_micro_usdt <> 0),
  currency char(4) not null default 'USDT' check (currency = 'USDT'),
  source_type text not null,
  source_id uuid not null,
  idempotency_key text not null unique,
  description text not null,
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id, kind, idempotency_key)
);
create index ledger_entries_user_created_idx
  on public.ledger_entries(user_id, created_at desc);

create table public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  amount_micro_usdt bigint not null check (amount_micro_usdt > 0),
  currency char(4) not null default 'USDT' check (currency = 'USDT'),
  state public.withdrawal_state not null default 'requested',
  network text not null default 'BEP20' check (network = 'BEP20'),
  destination_last4 text,
  provider_reference text,
  idempotency_key text not null unique,
  reviewed_by uuid references auth.users(id),
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id),
  event_type text not null,
  target_type text not null,
  target_id text,
  request_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Safe profile bootstrap. Username must be supplied in auth metadata by the
-- signup flow; the application should validate it before creating the user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_username text;
  ref_code text;
  ref_user uuid;
begin
  chosen_username := new.raw_user_meta_data ->> 'username';
  ref_code := new.raw_user_meta_data ->> 'referral_code';

  if chosen_username is null or chosen_username !~ '^[A-Za-z0-9_]{3,24}$' then
    raise exception 'A valid username is required';
  end if;

  if ref_code is not null and length(ref_code) > 0 then
    select id into ref_user
    from public.profiles
    where referral_code = ref_code;
    if ref_user is null then
      raise exception 'Invalid referral code';
    end if;
  end if;

  insert into public.profiles (id, username, referred_by)
  values (new.id, chosen_username, ref_user);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- RLS is enabled on every user-facing table. No client-side INSERT/UPDATE/DELETE
-- policies are granted for accounting/payment tables; trusted server functions
-- using the service role must validate every business operation.
alter table public.profiles enable row level security;
alter table public.packages enable row level security;
alter table public.payment_orders enable row level security;
alter table public.package_activations enable row level security;
alter table public.daily_video_claims enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.audit_events enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using (auth.uid() = id);

create policy "Authenticated users can read active packages"
  on public.packages for select to authenticated
  using (active = true);

create policy "Users can read their own payment orders"
  on public.payment_orders for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can read their own package activations"
  on public.package_activations for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can read their own video claims"
  on public.daily_video_claims for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can read their own ledger entries"
  on public.ledger_entries for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can read their own withdrawal requests"
  on public.withdrawal_requests for select to authenticated
  using (auth.uid() = user_id);

-- Deliberately no client policies for audit_events and no write policies for
-- payment_orders, package_activations, daily_video_claims, ledger_entries or
-- withdrawal_requests. Implement server-side RPC/Edge Functions before use.
-- Production TODO: add referral-cycle prevention, audited admin role, transaction
-- isolation/locking, provider webhook signature verification, and reviewed payouts.
