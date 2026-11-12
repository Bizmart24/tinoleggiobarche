-- TINO 2.0 · Tinoleggio Barche · schema, regole di accesso e funzioni di prenotazione
-- Da eseguire una volta in Supabase > SQL Editor (sostituisce il precedente supabase.sql).
create extension if not exists btree_gist;
create extension if not exists pgcrypto;

-- ---------- utenti e ruoli (i ruoli si assegnano solo dal server) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text, phone text, lang text default 'it',
  voice_enabled boolean default true, created_at timestamptz not null default now());
create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','staff')), granted_at timestamptz not null default now());
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.user_roles where user_id=auth.uid() and role='admin') $$;

-- ---------- catalogo, unità fisiche, prezzi (letti dal database, non dal testo del modello) ----------
create table if not exists public.fleet_models (
  id text primary key, name text not null, seats_max int not null, license_required boolean not null default false,
  requirement_note text, bookable boolean not null default false, booking_channel text not null default 'phone', external_url text,
  fuel_note text, source_url text, source_lang text, verified_at date, version int not null default 1);
create table if not exists public.physical_units (
  id uuid primary key default gen_random_uuid(), model_id text not null references public.fleet_models(id),
  label text not null, seats int, active boolean not null default true, notes text);
create table if not exists public.price_packages (
  id uuid primary key default gen_random_uuid(), model_id text not null references public.fleet_models(id),
  code text not null, label text not null, minutes int,            -- minutes = null finché l'azienda non conferma la fascia
  price_cents int not null, currency text not null default 'CHF', verified_at date, valid_from date, unique(model_id,code));
create table if not exists public.availability_blocks (
  id uuid primary key default gen_random_uuid(), unit_id uuid references public.physical_units(id) on delete cascade,
  model_id text references public.fleet_models(id), during tstzrange not null, reason text, created_by uuid, created_at timestamptz not null default now());
create table if not exists public.policies (key text primary key, value jsonb not null, note text, updated_at timestamptz not null default now());

-- ---------- preventivi, prenotazioni, operazioni ----------
create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id), version int not null default 1,
  model_id text not null references public.fleet_models(id), package_code text not null, starts_at timestamptz not null, ends_at timestamptz not null,
  occupants int not null, amount_cents int not null, currency text not null default 'CHF', to_be_determined jsonb not null default '[]',
  conditions jsonb not null default '{}', valid_until timestamptz, created_at timestamptz not null default now());
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(), code text unique, user_id uuid not null references auth.users(id),
  quote_id uuid not null references public.quotes(id), quote_version int not null, unit_id uuid not null references public.physical_units(id),
  during tstzrange not null,
  status text not null check (status in ('draft','quoted','held','pending','confirmed','cancelled','expired','failed','outcome_unknown')),
  payment_status text not null default 'not_required' check (payment_status in ('not_required','due','in_progress','succeeded','failed','refund_in_progress','refunded')),
  documents_status text not null default 'not_required' check (documents_status in ('not_required','missing','uploaded','to_review','approved','rejected','to_update')),
  hold_expires_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  -- due prenotazioni attive non possono sovrapporsi sulla stessa unità, nemmeno se confermate nello stesso istante
  constraint bookings_no_overlap exclude using gist (unit_id with =, during with &&) where (status in ('held','pending','confirmed')));
create table if not exists public.booking_participants (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id) on delete cascade,
  user_id uuid references auth.users(id), role text not null check (role in ('holder','driver','passenger')), full_name text);
create table if not exists public.operations (
  id uuid primary key, user_id uuid not null, kind text not null, status text not null default 'in_progress', result jsonb, created_at timestamptz not null default now());
create table if not exists public.action_confirmations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, action text not null, booking_id uuid references public.bookings(id),
  quote_id uuid, quote_version int, summary jsonb not null, expires_at timestamptz not null, used_at timestamptz);
create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id), provider text, provider_ref text,
  operation_id uuid, amount_cents int not null, currency text not null default 'CHF', status text not null default 'due', created_at timestamptz not null default now());

-- ---------- documenti personali, versioni, revisioni ----------
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id), subject_user_id uuid not null references auth.users(id),
  type text not null check (type in ('identity','passport','boat_license','other')), created_at timestamptz not null default now());
create table if not exists public.document_versions (
  id uuid primary key default gen_random_uuid(), document_id uuid not null references public.documents(id) on delete cascade, version int not null,
  storage_path text not null, status text not null default 'to_review' check (status in ('uploading','processing','unreadable','to_review','approved','rejected','to_update','expired')),
  fields jsonb not null default '{}', fields_source text, fields_confirmed boolean not null default false, expires_on date,
  created_at timestamptz not null default now(), unique(document_id,version));
create table if not exists public.booking_documents (
  booking_id uuid not null references public.bookings(id) on delete cascade, document_version_id uuid not null references public.document_versions(id), primary key(booking_id,document_version_id));
create table if not exists public.document_reviews (
  id uuid primary key default gen_random_uuid(), document_version_id uuid not null references public.document_versions(id), reviewer_id uuid not null,
  decision text not null check (decision in ('approved','rejected','to_update')), reason text, context text, created_at timestamptz not null default now());
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id), messages jsonb not null default '[]', updated_at timestamptz not null default now());
create table if not exists public.audit_events (
  id bigint generated always as identity primary key, actor_id uuid, action text not null, target text, meta jsonb not null default '{}', created_at timestamptz not null default now());
-- richieste al team e impostazioni pubbliche già usate dall'app
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(), ts bigint,
  kind text not null default 'booking', status text not null default 'new', data jsonb not null);
create table if not exists public.settings (id int primary key, data jsonb not null, updated_at timestamptz not null default now());

-- una versione già esaminata resta immutabile: correzioni = nuova versione da revisionare
create or replace function public.lock_reviewed_version() returns trigger language plpgsql as $$
begin
  if exists(select 1 from public.document_reviews r where r.document_version_id=old.id)
     and (new.storage_path is distinct from old.storage_path or new.fields is distinct from old.fields or new.expires_on is distinct from old.expires_on) then
    raise exception 'reviewed_version_is_immutable';
  end if;
  return new;
end $$;
drop trigger if exists trg_lock_reviewed on public.document_versions;
create trigger trg_lock_reviewed before update on public.document_versions for each row execute function public.lock_reviewed_version();

-- ---------- funzioni: preventivo, opzione, conferma, revisione ----------
create or replace function public.calculate_quote(p_model text, p_package text, p_starts timestamptz, p_occupants int)
returns public.quotes language plpgsql security definer set search_path=public as $$
declare m public.fleet_models; pk public.price_packages; q public.quotes;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into m from fleet_models where id=p_model; if not found then raise exception 'unknown_model'; end if;
  if not m.bookable then raise exception 'model_not_bookable_in_app'; end if;
  select * into pk from price_packages where model_id=p_model and code=p_package; if not found then raise exception 'unknown_package'; end if;
  if pk.minutes is null then raise exception 'package_slot_not_configured'; end if;
  if p_occupants<1 or p_occupants>m.seats_max then raise exception 'occupants_exceed_capacity'; end if;
  if p_starts<=now() then raise exception 'start_in_the_past'; end if;
  insert into quotes(user_id,model_id,package_code,starts_at,ends_at,occupants,amount_cents,currency,to_be_determined,conditions,valid_until)
  values(auth.uid(),p_model,p_package,p_starts,p_starts+make_interval(mins=>pk.minutes),p_occupants,pk.price_cents,pk.currency,
         case when m.fuel_note is not null then jsonb_build_array(m.fuel_note) else '[]'::jsonb end,
         jsonb_build_object('license_required',m.license_required,'requirement_note',m.requirement_note), now()+interval '30 minutes')
  returning * into q;
  return q;
end $$;

create or replace function public.create_hold(p_quote uuid, p_operation uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare q public.quotes; u record; b public.bookings; op public.operations; hold_min int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into op from operations where id=p_operation;
  if found then if op.user_id<>auth.uid() then raise exception 'forbidden'; end if; return op.result; end if;  -- stessa operazione: stesso esito, nessun doppione
  select * into q from quotes where id=p_quote and user_id=auth.uid(); if not found then raise exception 'unknown_quote'; end if;
  if q.valid_until<now() then raise exception 'quote_expired'; end if;
  insert into operations(id,user_id,kind) values(p_operation,auth.uid(),'create_hold');
  update bookings set status='expired',updated_at=now() where status='held' and hold_expires_at<now();
  select coalesce((value->>0)::int,15) into hold_min from policies where key='hold_minutes'; hold_min:=coalesce(hold_min,15);
  for u in select pu.id from physical_units pu where pu.model_id=q.model_id and pu.active
           and not exists(select 1 from availability_blocks ab where (ab.unit_id=pu.id or (ab.unit_id is null and (ab.model_id is null or ab.model_id=q.model_id))) and ab.during && tstzrange(q.starts_at,q.ends_at))
           order by pu.label loop
    begin
      insert into bookings(user_id,quote_id,quote_version,unit_id,during,status,hold_expires_at)
      values(auth.uid(),q.id,q.version,u.id,tstzrange(q.starts_at,q.ends_at),'held',now()+make_interval(mins=>hold_min)) returning * into b;
      exit;
    exception when exclusion_violation then null;   -- unità già occupata: prova la successiva
    end;
  end loop;
  if b.id is null then
    update operations set status='failed',result=jsonb_build_object('ok',false,'error','no_availability') where id=p_operation;
    return jsonb_build_object('ok',false,'error','no_availability');
  end if;
  insert into booking_participants(booking_id,user_id,role) values(b.id,auth.uid(),'holder');
  update operations set status='done',result=jsonb_build_object('ok',true,'booking_id',b.id,'status','held','hold_expires_at',b.hold_expires_at) where id=p_operation;
  return (select result from operations where id=p_operation);
end $$;

create or replace function public.prepare_confirmation(p_booking uuid)
returns public.action_confirmations language plpgsql security definer set search_path=public as $$
declare b public.bookings; q public.quotes; c public.action_confirmations;
begin
  select * into b from bookings where id=p_booking and user_id=auth.uid(); if not found then raise exception 'unknown_booking'; end if;
  select * into q from quotes where id=b.quote_id;
  insert into action_confirmations(user_id,action,booking_id,quote_id,quote_version,summary,expires_at)
  values(auth.uid(),'confirm_booking',b.id,q.id,q.version,
         jsonb_build_object('model',q.model_id,'package',q.package_code,'starts_at',q.starts_at,'ends_at',q.ends_at,'occupants',q.occupants,'amount_cents',q.amount_cents,'currency',q.currency,'to_be_determined',q.to_be_determined,'conditions',q.conditions),
         now()+interval '10 minutes') returning * into c;
  return c;
end $$;

create or replace function public.confirm_booking(p_booking uuid, p_confirmation uuid, p_operation uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare b public.bookings; q public.quotes; c public.action_confirmations; op public.operations; m public.fleet_models; docs_first boolean; has_license boolean; new_status text; res jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into op from operations where id=p_operation;
  if found then if op.user_id<>auth.uid() then raise exception 'forbidden'; end if; return op.result; end if;
  select * into b from bookings where id=p_booking and user_id=auth.uid() for update; if not found then raise exception 'unknown_booking'; end if;
  select * into q from quotes where id=b.quote_id;
  select * into c from action_confirmations where id=p_confirmation and user_id=auth.uid() and booking_id=b.id and action='confirm_booking';
  if not found then raise exception 'confirmation_not_valid'; end if;
  if c.used_at is not null or c.expires_at<now() then raise exception 'confirmation_expired_or_used'; end if;
  if c.quote_version<>q.version or b.quote_version<>q.version then raise exception 'summary_changed_confirm_again'; end if;
  insert into operations(id,user_id,kind) values(p_operation,auth.uid(),'confirm_booking');
  if b.status in ('confirmed','pending') then
    res:=jsonb_build_object('ok',true,'booking_id',b.id,'status',b.status,'code',b.code);
  else
    if b.status not in ('held','expired') then raise exception 'booking_not_confirmable'; end if;
    select * into m from fleet_models where id=q.model_id;
    select coalesce((value->>0)::boolean,true) into docs_first from policies where key='documents_before_confirmation'; docs_first:=coalesce(docs_first,true);
    has_license:=exists(select 1 from booking_documents bd join document_versions dv on dv.id=bd.document_version_id join documents d on d.id=dv.document_id
                        where bd.booking_id=b.id and d.type='boat_license' and dv.status='approved');
    new_status:=case when m.license_required and docs_first and not has_license then 'pending' else 'confirmed' end;
    begin
      -- se l'opzione era scaduta, il mezzo viene riacquisito solo se ancora libero
      update bookings set status=new_status, hold_expires_at=null, updated_at=now(),
             code=coalesce(code,'TN-'||upper(substr(encode(gen_random_bytes(4),'hex'),1,6))),
             documents_status=case when not m.license_required then 'not_required' when has_license then 'approved'
                                   when exists(select 1 from booking_documents where booking_id=b.id) then 'to_review' else 'missing' end
      where id=b.id returning * into b;
    exception when exclusion_violation then
      update operations set status='failed',result=jsonb_build_object('ok',false,'error','no_longer_available') where id=p_operation;
      return jsonb_build_object('ok',false,'error','no_longer_available');
    end;
    res:=jsonb_build_object('ok',true,'booking_id',b.id,'status',b.status,'code',b.code,'documents_status',b.documents_status);
  end if;
  update action_confirmations set used_at=now() where id=c.id;
  update operations set status='done',result=res where id=p_operation;
  insert into audit_events(actor_id,action,target,meta) values(auth.uid(),'confirm_booking',b.id::text,jsonb_build_object('status',b.status));
  return res;
end $$;

create or replace function public.admin_review_document(p_version uuid, p_decision text, p_reason text, p_context text default null)
returns public.document_versions language plpgsql security definer set search_path=public as $$
declare v public.document_versions;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if p_decision not in ('approved','rejected','to_update') then raise exception 'unknown_decision'; end if;
  if p_decision<>'approved' and coalesce(trim(p_reason),'')='' then raise exception 'reason_required'; end if;
  insert into document_reviews(document_version_id,reviewer_id,decision,reason,context) values(p_version,auth.uid(),p_decision,p_reason,p_context);
  update document_versions set status=p_decision where id=p_version returning * into v;
  if not found then raise exception 'unknown_version'; end if;
  insert into audit_events(actor_id,action,target,meta) values(auth.uid(),'review_document',p_version::text,jsonb_build_object('decision',p_decision));
  return v;
end $$;

-- ---------- regole di accesso ----------
alter table public.profiles enable row level security;            alter table public.user_roles enable row level security;
alter table public.fleet_models enable row level security;        alter table public.physical_units enable row level security;
alter table public.price_packages enable row level security;      alter table public.availability_blocks enable row level security;
alter table public.policies enable row level security;            alter table public.quotes enable row level security;
alter table public.bookings enable row level security;            alter table public.booking_participants enable row level security;
alter table public.operations enable row level security;          alter table public.action_confirmations enable row level security;
alter table public.payment_attempts enable row level security;    alter table public.documents enable row level security;
alter table public.document_versions enable row level security;   alter table public.booking_documents enable row level security;
alter table public.document_reviews enable row level security;    alter table public.conversations enable row level security;
alter table public.audit_events enable row level security;        alter table public.requests enable row level security;
alter table public.settings enable row level security;

create policy p_profiles_own on public.profiles for all to authenticated using (id=auth.uid() or public.is_admin()) with check (id=auth.uid() or public.is_admin());
create policy p_roles_read on public.user_roles for select to authenticated using (user_id=auth.uid() or public.is_admin());   -- nessuna regola di scrittura: i ruoli si assegnano da SQL Editor
create policy p_models_read on public.fleet_models for select to anon, authenticated using (true);
create policy p_models_admin on public.fleet_models for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_units_admin on public.physical_units for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_prices_read on public.price_packages for select to anon, authenticated using (true);
create policy p_prices_admin on public.price_packages for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_blocks_admin on public.availability_blocks for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_policies_read on public.policies for select to anon, authenticated using (true);
create policy p_policies_admin on public.policies for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_quotes_own on public.quotes for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy p_bookings_own on public.bookings for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy p_bookings_admin on public.bookings for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_part_read on public.booking_participants for select to authenticated using (user_id=auth.uid() or public.is_admin() or exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()));
create policy p_ops_own on public.operations for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy p_conf_own on public.action_confirmations for select to authenticated using (user_id=auth.uid() or public.is_admin());
create policy p_pay_read on public.payment_attempts for select to authenticated using (public.is_admin() or exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()));
-- documenti: li vede chi li ha caricati, la persona a cui si riferiscono e l'admin. L'intestatario della prenotazione NON vede le foto del conducente.
create policy p_docs_read on public.documents for select to authenticated using (owner_id=auth.uid() or subject_user_id=auth.uid() or public.is_admin());
create policy p_docs_insert on public.documents for insert to authenticated with check (owner_id=auth.uid() and subject_user_id=auth.uid());
create policy p_docv_read on public.document_versions for select to authenticated using (public.is_admin() or exists(select 1 from public.documents d where d.id=document_id and (d.owner_id=auth.uid() or d.subject_user_id=auth.uid())));
create policy p_docv_insert on public.document_versions for insert to authenticated with check (status in ('uploading','to_review') and exists(select 1 from public.documents d where d.id=document_id and d.owner_id=auth.uid()));
create policy p_docv_update on public.document_versions for update to authenticated using (exists(select 1 from public.documents d where d.id=document_id and d.owner_id=auth.uid())) with check (status in ('uploading','to_review'));
create policy p_bdocs_read on public.booking_documents for select to authenticated using (public.is_admin() or exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()));
create policy p_bdocs_insert on public.booking_documents for insert to authenticated with check (exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()) and exists(select 1 from public.document_versions dv join public.documents d on d.id=dv.document_id where dv.id=document_version_id and d.owner_id=auth.uid()));
create policy p_reviews_read on public.document_reviews for select to authenticated using (public.is_admin() or exists(select 1 from public.document_versions dv join public.documents d on d.id=dv.document_id where dv.id=document_version_id and d.owner_id=auth.uid()));
create policy p_conv_own on public.conversations for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy p_audit_admin on public.audit_events for select to authenticated using (public.is_admin());
create policy p_req_insert on public.requests for insert to anon, authenticated with check (status='new');
create policy p_req_admin_read on public.requests for select to authenticated using (public.is_admin());
create policy p_req_admin_upd on public.requests for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy p_settings_read on public.settings for select to anon, authenticated using (true);
create policy p_settings_admin_ins on public.settings for insert to authenticated with check (public.is_admin());
create policy p_settings_admin_upd on public.settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

grant usage on schema public to anon, authenticated;
grant select on public.fleet_models, public.price_packages, public.policies, public.settings to anon;
grant insert on public.requests to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on function public.calculate_quote(text,text,timestamptz,int), public.create_hold(uuid,uuid), public.prepare_confirmation(uuid), public.confirm_booking(uuid,uuid,uuid), public.admin_review_document(uuid,text,text,text), public.is_admin() to authenticated;
