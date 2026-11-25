-- =====================================================================
--  Live-Umfrage-Tool: einmalige Einrichtung in Supabase
--  So geht es: Supabase-Dashboard -> SQL Editor -> "New query"
--  -> diesen kompletten Text einfügen -> "Run".
--  Das Skript darf mehrfach ausgeführt werden, vorhandene Umfragen bleiben.
-- =====================================================================

create table if not exists public.umfragen (
  code         text primary key,
  frage        text not null,
  typ          text not null check (typ in ('einfach','mehrfach','skala','wolke')),
  optionen     jsonb not null default '[]'::jsonb,
  offen        boolean not null default true,
  runde        integer not null default 1,
  ausgeblendet jsonb not null default '[]'::jsonb,
  mod_hash     text not null,
  erstellt     timestamptz not null default now()
);

create table if not exists public.stimmen (
  code    text not null references public.umfragen(code) on delete cascade,
  runde   integer not null,
  geraet  text not null,
  antwort jsonb not null,
  zeit    timestamptz not null default now(),
  primary key (code, runde, geraet)
);

-- Kein direkter Zugriff von außen: Row Level Security an, keine Regeln.
-- Alles läuft ausschließlich über die Funktionen unten.
alter table public.umfragen enable row level security;
alter table public.stimmen  enable row level security;
revoke all on public.umfragen from anon, authenticated;
revoke all on public.stimmen  from anon, authenticated;

-- ---------------------------------------------------------------------
-- Hilfsfunktionen (nicht von außen aufrufbar)
-- ---------------------------------------------------------------------
create or replace function public._umfrage_hash(p_mod text)
returns text language sql immutable as $$
  select encode(sha256(convert_to(coalesce(p_mod,''), 'UTF8')), 'hex')
$$;

create or replace function public._umfrage_pruefen(p_code text, p_mod text)
returns public.umfragen language plpgsql security definer set search_path = public as $$
declare u public.umfragen;
begin
  select * into u from umfragen where code = upper(trim(p_code));
  if not found then raise exception 'Umfrage nicht gefunden'; end if;
  if length(coalesce(p_mod,'')) < 16 or u.mod_hash <> _umfrage_hash(p_mod) then
    raise exception 'Kein Zugriff: falscher Moderations-Schlüssel';
  end if;
  return u;
end $$;

-- ---------------------------------------------------------------------
-- 1. Umfrage anlegen
-- ---------------------------------------------------------------------
create or replace function public.umfrage_anlegen(p_frage text, p_typ text, p_optionen jsonb, p_mod text)
returns json language plpgsql security definer set search_path = public as $$
declare
  zeichen constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  neu text; i int; versuch int := 0; n int; opt jsonb := coalesce(p_optionen, '[]'::jsonb);
begin
  p_frage := trim(coalesce(p_frage,''));
  if length(p_frage) < 1 or length(p_frage) > 300 then raise exception 'Die Frage muss 1 bis 300 Zeichen haben'; end if;
  if p_typ not in ('einfach','mehrfach','skala','wolke') then raise exception 'Unbekannter Fragetyp'; end if;
  if length(coalesce(p_mod,'')) < 16 then raise exception 'Moderations-Schlüssel fehlt'; end if;
  if jsonb_typeof(opt) <> 'array' then raise exception 'Antworten müssen eine Liste sein'; end if;
  n := jsonb_array_length(opt);
  if p_typ in ('einfach','mehrfach') and (n < 2 or n > 12) then raise exception 'Bitte 2 bis 12 Antworten angeben'; end if;
  if p_typ = 'skala' and n <> 2 then raise exception 'Die Skala braucht genau 2 Beschriftungen'; end if;
  if p_typ = 'wolke' then opt := '[]'::jsonb; end if;
  if exists (select 1 from jsonb_array_elements(opt) e where jsonb_typeof(e) <> 'string' or length(e #>> '{}') > 80) then
    raise exception 'Jede Antwort darf höchstens 80 Zeichen haben';
  end if;
  if (select count(*) from umfragen where erstellt > now() - interval '1 hour') > 300 then
    raise exception 'Zu viele neue Umfragen in kurzer Zeit. Bitte später erneut versuchen.';
  end if;
  loop
    neu := '';
    for i in 1..4 loop neu := neu || substr(zeichen, 1 + floor(random() * length(zeichen))::int, 1); end loop;
    exit when not exists (select 1 from umfragen where code = neu);
    versuch := versuch + 1;
    if versuch > 50 then raise exception 'Kein freier Code gefunden'; end if;
  end loop;
  insert into umfragen(code, frage, typ, optionen, mod_hash) values (neu, p_frage, p_typ, opt, _umfrage_hash(p_mod));
  return json_build_object('code', neu);
end $$;

-- ---------------------------------------------------------------------
-- 2. Umfrage laden (für die Abstimmseite, ohne Geheimnisse)
-- ---------------------------------------------------------------------
create or replace function public.umfrage_laden(p_code text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('code', code, 'frage', frage, 'typ', typ, 'optionen', optionen, 'offen', offen, 'runde', runde)
  from umfragen where code = upper(trim(p_code))
$$;

-- ---------------------------------------------------------------------
-- 3. Stimme abgeben (erneutes Abstimmen überschreibt die alte Stimme)
-- ---------------------------------------------------------------------
create or replace function public.stimme_abgeben(p_code text, p_geraet text, p_antwort jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare
  u umfragen; n int; a jsonb := '[]'::jsonb; e jsonb; w text; k int;
  sperre constant text[] := array['arsch','fick','fotze','hure','nazi','neger','nigger','schlampe','wichser','hitler','fuck','shit','bitch','cunt','porn'];
begin
  select * into u from umfragen where code = upper(trim(p_code));
  if not found then raise exception 'Umfrage nicht gefunden'; end if;
  if not u.offen then raise exception 'Die Umfrage ist geschlossen'; end if;
  if length(coalesce(p_geraet,'')) < 8 or length(p_geraet) > 64 then raise exception 'Ungültiges Gerät'; end if;
  if p_antwort is null or jsonb_typeof(p_antwort) <> 'array' then raise exception 'Ungültige Antwort'; end if;
  n := jsonb_array_length(u.optionen);

  if u.typ in ('einfach','mehrfach','skala') then
    for e in select * from jsonb_array_elements(p_antwort) loop
      if jsonb_typeof(e) <> 'number' then raise exception 'Ungültige Antwort'; end if;
      k := (e #>> '{}')::numeric::int;
      if u.typ = 'skala' and (k < 1 or k > 10) then raise exception 'Ungültige Antwort'; end if;
      if u.typ <> 'skala' and (k < 0 or k >= n) then raise exception 'Ungültige Antwort'; end if;
      if not a @> to_jsonb(k) then a := a || to_jsonb(k); end if;
    end loop;
    if jsonb_array_length(a) < 1 then raise exception 'Bitte eine Antwort wählen'; end if;
    if u.typ <> 'mehrfach' and jsonb_array_length(a) > 1 then raise exception 'Nur eine Antwort erlaubt'; end if;
  else
    for e in select * from jsonb_array_elements(p_antwort) loop
      if jsonb_typeof(e) <> 'string' then raise exception 'Ungültige Antwort'; end if;
      w := regexp_replace(trim(e #>> '{}'), '\s+', ' ', 'g');
      if length(w) = 0 then continue; end if;
      if length(w) > 30 then raise exception 'Höchstens 30 Zeichen pro Begriff'; end if;
      if exists (select 1 from unnest(sperre) s where lower(w) like '%' || s || '%') then continue; end if;
      if not a @> to_jsonb(w) then a := a || to_jsonb(w); end if;
    end loop;
    if jsonb_array_length(a) < 1 then raise exception 'Bitte mindestens einen Begriff eingeben'; end if;
    if jsonb_array_length(a) > 3 then raise exception 'Höchstens 3 Begriffe'; end if;
  end if;

  insert into stimmen(code, runde, geraet, antwort) values (u.code, u.runde, p_geraet, a)
  on conflict (code, runde, geraet) do update set antwort = excluded.antwort, zeit = now();
  return json_build_object('ok', true, 'runde', u.runde);
end $$;

-- ---------------------------------------------------------------------
-- 4. Ergebnis lesen (für die Live-Seite)
-- ---------------------------------------------------------------------
create or replace function public.umfrage_ergebnis(p_code text)
returns json language plpgsql stable security definer set search_path = public as $$
declare u umfragen; anz int; werte json;
begin
  select * into u from umfragen where code = upper(trim(p_code));
  if not found then raise exception 'Umfrage nicht gefunden'; end if;
  select count(*) into anz from stimmen where code = u.code and runde = u.runde;
  if u.typ = 'wolke' then
    select coalesce(json_agg(json_build_object('wort', wort, 'anzahl', anzahl) order by anzahl desc, wort), '[]'::json) into werte
    from (
      select min(e) as wort, count(*) as anzahl
      from stimmen s, jsonb_array_elements_text(s.antwort) e
      where s.code = u.code and s.runde = u.runde
        and not (u.ausgeblendet ? lower(e))
      group by lower(e)
      order by count(*) desc, lower(e)
      limit 60
    ) t;
  else
    select coalesce(json_object_agg(k, c), '{}'::json) into werte
    from (
      select e::int as k, count(*) as c
      from stimmen s, jsonb_array_elements_text(s.antwort) e
      where s.code = u.code and s.runde = u.runde
      group by e::int
    ) t;
  end if;
  return json_build_object('code', u.code, 'frage', u.frage, 'typ', u.typ, 'optionen', u.optionen,
                           'offen', u.offen, 'runde', u.runde, 'anzahl', anz, 'werte', werte);
end $$;

-- ---------------------------------------------------------------------
-- 5. Umfrage steuern (nur mit Moderations-Schlüssel)
--    Aktionen: oeffnen, schliessen, neue_runde, ausblenden, einblenden, loeschen
-- ---------------------------------------------------------------------
create or replace function public.umfrage_steuern(p_code text, p_mod text, p_aktion text, p_wert text default null)
returns json language plpgsql security definer set search_path = public as $$
declare u umfragen;
begin
  u := _umfrage_pruefen(p_code, p_mod);
  if p_aktion = 'oeffnen' then
    update umfragen set offen = true where code = u.code;
  elsif p_aktion = 'schliessen' then
    update umfragen set offen = false where code = u.code;
  elsif p_aktion = 'neue_runde' then
    update umfragen set runde = runde + 1, offen = true, ausgeblendet = '[]'::jsonb where code = u.code;
    delete from stimmen where code = u.code and runde <= u.runde;  -- alte Stimmen weg, Datenbank bleibt schlank
  elsif p_aktion = 'ausblenden' then
    if not (u.ausgeblendet ? lower(trim(coalesce(p_wert,'')))) then
      update umfragen set ausgeblendet = ausgeblendet || to_jsonb(lower(trim(coalesce(p_wert,'')))) where code = u.code;
    end if;
  elsif p_aktion = 'einblenden' then
    update umfragen set ausgeblendet = '[]'::jsonb where code = u.code;
  elsif p_aktion = 'loeschen' then
    delete from umfragen where code = u.code;
    return json_build_object('ok', true, 'geloescht', true);
  else
    raise exception 'Unbekannte Aktion';
  end if;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 6. Meine Umfragen (Liste für die Zentrale, nur mit Moderations-Schlüssel)
-- ---------------------------------------------------------------------
create or replace function public.meine_umfragen(p_mod text)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
           'code', u.code, 'frage', u.frage, 'typ', u.typ, 'optionen', u.optionen, 'offen', u.offen, 'runde', u.runde,
           'erstellt', u.erstellt,
           'anzahl', (select count(*) from stimmen s where s.code = u.code and s.runde = u.runde))
         order by u.erstellt desc), '[]'::json)
  from umfragen u
  where length(coalesce(p_mod,'')) >= 16 and u.mod_hash = _umfrage_hash(p_mod)
$$;

-- ---------------------------------------------------------------------
-- Rechte: nur die 6 Funktionen sind von außen aufrufbar
-- ---------------------------------------------------------------------
revoke all on function public._umfrage_hash(text) from public, anon, authenticated;
revoke all on function public._umfrage_pruefen(text, text) from public, anon, authenticated;
revoke all on function public.umfrage_anlegen(text, text, jsonb, text) from public;
revoke all on function public.umfrage_laden(text) from public;
revoke all on function public.stimme_abgeben(text, text, jsonb) from public;
revoke all on function public.umfrage_ergebnis(text) from public;
revoke all on function public.umfrage_steuern(text, text, text, text) from public;
revoke all on function public.meine_umfragen(text) from public;
grant execute on function public.umfrage_anlegen(text, text, jsonb, text) to anon, authenticated;
grant execute on function public.umfrage_laden(text) to anon, authenticated;
grant execute on function public.stimme_abgeben(text, text, jsonb) to anon, authenticated;
grant execute on function public.umfrage_ergebnis(text) to anon, authenticated;
grant execute on function public.umfrage_steuern(text, text, text, text) to anon, authenticated;
grant execute on function public.meine_umfragen(text) to anon, authenticated;
