-- Ti Noleggio Barche: tabelle e regole di accesso per Supabase
-- Da incollare in Supabase > SQL Editor ed eseguire una volta.

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  ts bigint,
  kind text not null default 'booking',   -- booking | gift | group
  status text not null default 'new',     -- new | confirmed | rejected | done
  data jsonb not null
);
create table if not exists public.settings (
  id int primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.requests enable row level security;
alter table public.settings enable row level security;

-- I clienti (non autenticati) possono solo inviare nuove richieste.
create policy "clienti inviano richieste" on public.requests
  for insert to anon, authenticated with check (status = 'new');
-- Solo il gestore autenticato legge, aggiorna ed elimina le richieste.
create policy "gestore legge richieste" on public.requests
  for select to authenticated using (true);
create policy "gestore aggiorna richieste" on public.requests
  for update to authenticated using (true) with check (true);
create policy "gestore elimina richieste" on public.requests
  for delete to authenticated using (true);

-- Prezzi, avvisi, date bloccate: tutti leggono, solo il gestore scrive.
create policy "tutti leggono impostazioni" on public.settings
  for select to anon, authenticated using (true);
create policy "gestore crea impostazioni" on public.settings
  for insert to authenticated with check (true);
create policy "gestore aggiorna impostazioni" on public.settings
  for update to authenticated using (true) with check (true);

-- Poi: Authentication > Users > Add user, per creare e-mail e password del gestore.
-- Disattiva le iscrizioni libere (Authentication > Sign In / Providers) per evitare altri accessi.
