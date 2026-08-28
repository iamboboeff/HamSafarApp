-- Read-only Telegram marketplace. Rows are written only by the server-side
-- collector using service_role; mobile clients can only read active leads.

create table if not exists public.telegram_ride_leads (
  id uuid default gen_random_uuid() primary key,
  source_batch_key text not null unique,
  source_chat_id bigint not null,
  source_chat_title text,
  source_chat_username text,
  source_message_ids bigint[] not null default '{}',
  source_message_url text,
  author_id bigint,
  author_name text,
  author_username text,
  kind text not null check (kind in ('offer', 'request')),
  from_city text not null,
  to_city text not null,
  departure_date date,
  departure_time time without time zone,
  date_precision text not null default 'unknown'
    check (date_precision in ('exact', 'fuzzy', 'unknown')),
  seats integer check (seats is null or seats between 1 and 20),
  cargo boolean not null default false,
  price integer check (price is null or price >= 0),
  currency text check (currency is null or currency in ('TJS', 'UZS')),
  phone text,
  contact_methods text[] not null default '{}',
  raw_text text not null,
  source_sent_at timestamptz not null,
  confidence numeric not null check (confidence between 0 and 1),
  status text not null default 'active' check (status in ('active', 'expired', 'hidden')),
  expires_at timestamptz not null default (now() + interval '2 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists telegram_ride_leads_route_idx
  on public.telegram_ride_leads (from_city, to_city, departure_date);
create index if not exists telegram_ride_leads_active_idx
  on public.telegram_ride_leads (status, expires_at desc, source_sent_at desc);
create index if not exists telegram_ride_leads_author_idx
  on public.telegram_ride_leads (source_chat_id, author_id, source_sent_at desc);

drop trigger if exists set_telegram_ride_leads_updated_at
  on public.telegram_ride_leads;
create trigger set_telegram_ride_leads_updated_at
  before update on public.telegram_ride_leads
  for each row execute function public.set_updated_at();

alter table public.telegram_ride_leads enable row level security;

drop policy if exists telegram_ride_leads_read_active on public.telegram_ride_leads;
create policy telegram_ride_leads_read_active
  on public.telegram_ride_leads for select
  to anon, authenticated
  using (status = 'active' and expires_at > now());

drop policy if exists telegram_ride_leads_service_role_all on public.telegram_ride_leads;
create policy telegram_ride_leads_service_role_all
  on public.telegram_ride_leads for all
  to service_role
  using (true) with check (true);

revoke insert, update, delete on public.telegram_ride_leads from anon, authenticated;
grant select on public.telegram_ride_leads to anon, authenticated;
grant all on public.telegram_ride_leads to service_role;
