-- =====================================================================
-- Ghisa · database (Supabase / Postgres)
-- Incolla tutto nel SQL Editor di Supabase ed esegui una volta.
--
-- Ruoli:
--   super admin   → utenti.super_admin = true, vede e modifica tutto
--   admin         → proprietario della palestra (tabella membri)
--   coach         → crea schede e note per i suoi atleti
--   atleta        → legge la propria scheda e registra i propri allenamenti
--
-- La scheda (cosa è previsto) è separata dagli allenamenti (cosa è stato
-- fatto): l'atleta non modifica mai la scheda del coach, registra solo
-- pesi, ripetizioni e note sue.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Tipi
-- ---------------------------------------------------------------------

create type public.ruolo as enum ('admin', 'coach', 'atleta');
create type public.tipo_elemento as enum ('macchinario', 'zona');


-- ---------------------------------------------------------------------
-- Utenti e palestre
-- ---------------------------------------------------------------------

-- Gli utenti dell'app: una riga per ogni account (creata in automatico alla registrazione).
create table public.utenti (
    id          uuid primary key references auth.users (id) on delete cascade,
    nome        text not null default '',
    email       text,
    super_admin boolean not null default false,
    creato_il   timestamptz not null default now()
);

create table public.palestre (
    id           uuid primary key default gen_random_uuid(),
    nome         text not null,
    indirizzo    text,
    proprietario uuid references public.utenti (id) on delete set null,
    creato_il    timestamptz not null default now()
);

-- Chi fa parte di quale palestra e con che ruolo.
-- Una persona può avere più ruoli (es. il proprietario che fa anche il coach).
create table public.membri (
    palestra_id uuid not null references public.palestre (id) on delete cascade,
    utente_id   uuid not null references public.utenti (id) on delete cascade,
    ruolo       public.ruolo not null,
    attivo      boolean not null default true,
    creato_il   timestamptz not null default now(),
    primary key (palestra_id, utente_id, ruolo)
);
create index on public.membri (utente_id);

-- Quale coach segue quale atleta. Lo decide l'admin della palestra.
create table public.coach (
    palestra_id uuid not null references public.palestre (id) on delete cascade,
    coach_id    uuid not null references public.utenti (id) on delete cascade,
    atleta_id   uuid not null references public.utenti (id) on delete cascade,
    primary key (palestra_id, coach_id, atleta_id)
);
create index on public.coach (atleta_id);


-- ---------------------------------------------------------------------
-- Anagrafica esercizi
-- ---------------------------------------------------------------------

-- palestra_id vuoto = esercizio comune a tutte le palestre (lo gestisce il super admin).
create table public.esercizi (
    id          uuid primary key default gen_random_uuid(),
    palestra_id uuid references public.palestre (id) on delete cascade,
    nome        text not null,
    -- "Panca piana" e "PANCA PIANA" sono lo stesso esercizio (come nell'app di oggi).
    nome_norm   text generated always as (upper(regexp_replace(nome, '[^[:alnum:]]', '', 'g'))) stored,
    gruppo      text,
    note        text,
    creato_da   uuid references public.utenti (id) on delete set null,
    creato_il   timestamptz not null default now(),
    unique nulls not distinct (palestra_id, nome_norm)
);


-- ---------------------------------------------------------------------
-- Schede (scritte da admin o coach)
-- ---------------------------------------------------------------------

create table public.schede (
    id            uuid primary key default gen_random_uuid(),
    palestra_id   uuid not null references public.palestre (id) on delete cascade,
    atleta_id     uuid not null references public.utenti (id) on delete cascade,
    autore_id     uuid references public.utenti (id) on delete set null,
    titolo        text not null,
    inizio        date,
    fine          date,
    attiva        boolean not null default true,
    note          text,
    creato_il     timestamptz not null default now(),
    aggiornato_il timestamptz not null default now()
);
create index on public.schede (atleta_id);
create index on public.schede (palestra_id);

-- Giorni della scheda (A, B, C…).
create table public.giorni (
    id            uuid primary key default gen_random_uuid(),
    scheda_id     uuid not null references public.schede (id) on delete cascade,
    ordine        int not null default 0,
    nome          text not null,
    aggiornato_il timestamptz not null default now()
);
create index on public.giorni (scheda_id);

-- Esercizi di un giorno con le indicazioni del coach.
create table public.esercizi_giorno (
    id               uuid primary key default gen_random_uuid(),
    giorno_id        uuid not null references public.giorni (id) on delete cascade,
    esercizio_id     uuid not null references public.esercizi (id),
    ordine           int not null default 0,
    serie            int,
    ripetizioni      text,          -- testo libero: "10", "8-10", "max", "30\""
    recupero_sec     int,
    carico           text,          -- carico suggerito: "60 kg", "RPE 8"…
    note             text,          -- nota del coach su questo esercizio
    aggiornato_il    timestamptz not null default now()
);
create index on public.esercizi_giorno (giorno_id);

-- Note personali di un atleta su un esercizio ("male alla spalla", "sedile al 4").
-- Sono legate ad atleta + esercizio, non alla scheda: restano anche quando arriva
-- una scheda nuova. Le scrive l'atleta; il suo coach e l'admin le leggono e
-- possono aggiungerne di loro.
-- (L'indicazione del coach dentro la scheda sta in esercizi_giorno.note,
--  quella di un singolo allenamento in allenamenti.note e serie_svolte.note.)
create table public.note (
    id            uuid primary key default gen_random_uuid(),
    atleta_id     uuid not null references public.utenti (id) on delete cascade,
    esercizio_id  uuid not null references public.esercizi (id) on delete cascade,
    autore_id     uuid not null references public.utenti (id) on delete cascade,
    testo         text not null,
    creato_il     timestamptz not null default now(),
    aggiornato_il timestamptz not null default now()
);
create index on public.note (atleta_id, esercizio_id);


-- ---------------------------------------------------------------------
-- Allenamenti (registrati dall'atleta)
-- ---------------------------------------------------------------------

create table public.allenamenti (
    id            uuid primary key default gen_random_uuid(),
    atleta_id     uuid not null references public.utenti (id) on delete cascade,
    scheda_id     uuid not null references public.schede (id) on delete cascade,
    giorno_id     uuid references public.giorni (id) on delete set null,
    inizio        timestamptz not null default now(),
    fine          timestamptz,
    note          text,
    aggiornato_il timestamptz not null default now()
);
create index on public.allenamenti (atleta_id, inizio desc);
create index on public.allenamenti (scheda_id);

create table public.serie_svolte (
    id                  uuid primary key default gen_random_uuid(),
    allenamento_id      uuid not null references public.allenamenti (id) on delete cascade,
    esercizio_giorno_id uuid references public.esercizi_giorno (id) on delete set null,
    numero              int not null,
    peso                numeric(6, 2),
    ripetizioni         int,
    completata          boolean not null default true,
    note                text,
    aggiornato_il       timestamptz not null default now()
);
create index on public.serie_svolte (allenamento_id);


-- ---------------------------------------------------------------------
-- Mappa della palestra (come nell'app: sale su griglia, macchinari e zone)
-- ---------------------------------------------------------------------

create table public.sale (
    id          uuid primary key default gen_random_uuid(),
    palestra_id uuid not null references public.palestre (id) on delete cascade,
    nome        text not null,
    colonne     int not null default 8,
    righe       int not null default 12,
    ordine      int not null default 0
);
create index on public.sale (palestra_id);

create table public.macchinari (
    id            uuid primary key default gen_random_uuid(),
    sala_id       uuid not null references public.sale (id) on delete cascade,
    tipo          public.tipo_elemento not null default 'macchinario',
    nome          text not null,
    colonna       int not null default 1,
    riga          int not null default 1,
    larghezza     int not null default 1,
    altezza       int not null default 1,
    colore        int not null default 0,
    foto          text,         -- percorso nello Storage: <palestra_id>/<file>.jpg
    aggiornato_il timestamptz not null default now()
);
create index on public.macchinari (sala_id);

-- Dove si fa un esercizio in una palestra e come si imposta la macchina.
create table public.esercizi_macchinari (
    palestra_id    uuid not null references public.palestre (id) on delete cascade,
    esercizio_id   uuid not null references public.esercizi (id) on delete cascade,
    macchinario_id uuid not null references public.macchinari (id) on delete cascade,
    impostazione   text not null default '',
    primary key (palestra_id, esercizio_id)
);


-- ---------------------------------------------------------------------
-- Automatismi
-- ---------------------------------------------------------------------

-- Crea la riga in "utenti" quando qualcuno si registra.
create function public.crea_utente() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    insert into public.utenti (id, nome, email)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'nome', ''), new.email);
    return new;
end $$;

create trigger nuovo_utente after insert on auth.users
    for each row execute function public.crea_utente();

-- Aggiorna "aggiornato_il" a ogni modifica (serve alla sincronizzazione delle app).
create function public.tocca() returns trigger
language plpgsql set search_path = '' as $$
begin
    new.aggiornato_il = now();
    return new;
end $$;

create trigger tocca before update on public.schede          for each row execute function public.tocca();
create trigger tocca before update on public.giorni          for each row execute function public.tocca();
create trigger tocca before update on public.esercizi_giorno for each row execute function public.tocca();
create trigger tocca before update on public.allenamenti     for each row execute function public.tocca();
create trigger tocca before update on public.serie_svolte    for each row execute function public.tocca();
create trigger tocca before update on public.macchinari      for each row execute function public.tocca();
create trigger tocca before update on public.note            for each row execute function public.tocca();


-- =====================================================================
-- PERMESSI (Row Level Security)
-- Le funzioni qui sotto rispondono a "chi sono io in questa palestra?".
-- Valgono per tutte le app (iPhone, Android, web): il database rifiuta
-- qualsiasi richiesta che non rispetta queste regole.
-- =====================================================================

-- Sono super admin?
create function public.sono_super() returns boolean
language sql stable security definer set search_path = '' as $$
    select coalesce((select super_admin from public.utenti where id = auth.uid()), false)
$$;

-- Ho uno di questi ruoli nella palestra? (il super admin li ha tutti)
create function public.ho_ruolo(p uuid, ruoli public.ruolo[]) returns boolean
language sql stable security definer set search_path = '' as $$
    select public.sono_super() or exists (
        select 1 from public.membri m
        where m.palestra_id = p and m.utente_id = auth.uid()
          and m.ruolo = any (ruoli) and m.attivo
    )
$$;

-- Faccio parte della palestra, con qualsiasi ruolo?
create function public.sono_membro(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select public.ho_ruolo(p, array['admin', 'coach', 'atleta']::public.ruolo[])
$$;

-- Posso vedere e seguire questo atleta? (lui stesso, l'admin, il suo coach, il super admin)
create function public.seguo_atleta(p uuid, atleta uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select atleta = auth.uid()
        or public.ho_ruolo(p, array['admin']::public.ruolo[])
        or (public.ho_ruolo(p, array['coach']::public.ruolo[]) and exists (
                select 1 from public.coach c
                where c.palestra_id = p and c.coach_id = auth.uid() and c.atleta_id = atleta))
$$;

-- Posso scrivere schede per questo atleta? (admin, suo coach, super admin; mai l'atleta)
create function public.scrivo_per(p uuid, atleta uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (                                         -- deve essere un atleta della palestra
               select 1 from public.membri m
               where m.palestra_id = p and m.utente_id = atleta and m.ruolo = 'atleta')
       and (public.ho_ruolo(p, array['admin']::public.ruolo[])
            or (public.ho_ruolo(p, array['coach']::public.ruolo[]) and exists (
                    select 1 from public.coach c
                    where c.palestra_id = p and c.coach_id = auth.uid() and c.atleta_id = atleta)))
$$;

-- Posso seguire questo atleta in almeno una delle sue palestre? (per le note, che non hanno palestra)
create function public.vedo_atleta(atleta uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select atleta = auth.uid() or public.sono_super() or exists (
        select 1 from public.membri m
        where m.utente_id = atleta and m.ruolo = 'atleta'
          and public.seguo_atleta(m.palestra_id, atleta))
$$;

create function public.vedo_scheda(s uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.schede x where x.id = s and public.seguo_atleta(x.palestra_id, x.atleta_id))
$$;

create function public.scrivo_scheda(s uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.schede x where x.id = s and public.scrivo_per(x.palestra_id, x.atleta_id))
$$;

create function public.scheda_del_giorno(g uuid) returns uuid
language sql stable security definer set search_path = '' as $$
    select scheda_id from public.giorni where id = g
$$;

create function public.palestra_della_sala(s uuid) returns uuid
language sql stable security definer set search_path = '' as $$
    select palestra_id from public.sale where id = s
$$;

-- Allenamento mio (posso modificarlo) / visibile (atleta, coach, admin, super).
create function public.mio_allenamento(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.allenamenti x where x.id = a and x.atleta_id = auth.uid())
$$;

create function public.vedo_allenamento(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.allenamenti x where x.id = a and public.vedo_scheda(x.scheda_id))
$$;


-- Accendi la RLS su tutte le tabelle: senza una regola che lo permette, nulla è visibile.
alter table public.utenti         enable row level security;
alter table public.palestre        enable row level security;
alter table public.membri          enable row level security;
alter table public.coach           enable row level security;
alter table public.esercizi        enable row level security;
alter table public.schede          enable row level security;
alter table public.giorni          enable row level security;
alter table public.esercizi_giorno enable row level security;
alter table public.note            enable row level security;
alter table public.allenamenti     enable row level security;
alter table public.serie_svolte    enable row level security;
alter table public.sale            enable row level security;
alter table public.macchinari      enable row level security;
alter table public.esercizi_macchinari enable row level security;

-- UTENTI: vedi il tuo e quelli delle persone delle tue palestre.
-- Puoi cambiare solo il tuo nome (super_admin non è modificabile dall'app).
-- Staff (admin, coach) vede tutti i membri; l'atleta vede lo staff ma non gli altri atleti.
create function public.vedo_utente(utente uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select utente = auth.uid() or public.sono_super() or exists (
        select 1 from public.membri io join public.membri lui using (palestra_id)
        where io.utente_id = auth.uid() and lui.utente_id = utente and io.attivo
          and (io.ruolo in ('admin', 'coach') or lui.ruolo in ('admin', 'coach')))
$$;

create policy "utenti: lettura" on public.utenti for select using (public.vedo_utente(id));
create policy "utenti: modifica" on public.utenti for update
    using (id = auth.uid() or public.sono_super())
    with check (id = auth.uid() or public.sono_super());
revoke update on public.utenti from authenticated;
grant update (nome) on public.utenti to authenticated;

-- PALESTRE: le vedono i membri; le crea e cancella il super admin, le modifica l'admin.
create policy "palestre: lettura" on public.palestre for select using (public.sono_membro(id));
create policy "palestre: crea"    on public.palestre for insert with check (public.sono_super());
create policy "palestre: modifica" on public.palestre for update
    using (public.ho_ruolo(id, array['admin']::public.ruolo[]))
    with check (public.ho_ruolo(id, array['admin']::public.ruolo[]));
create policy "palestre: elimina" on public.palestre for delete using (public.sono_super());

-- MEMBRI: ognuno vede i propri ruoli; admin e coach vedono tutti i membri; solo l'admin li gestisce.
create policy "membri: lettura" on public.membri for select using (
    utente_id = auth.uid() or public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[])
);
create policy "membri: gestione" on public.membri for all
    using (public.ho_ruolo(palestra_id, array['admin']::public.ruolo[]))
    with check (public.ho_ruolo(palestra_id, array['admin']::public.ruolo[]));

-- COACH ↔ ATLETI: li vedono gli interessati e l'admin, li assegna l'admin.
create policy "coach: lettura" on public.coach for select using (
    coach_id = auth.uid() or atleta_id = auth.uid() or public.ho_ruolo(palestra_id, array['admin']::public.ruolo[])
);
create policy "coach: gestione" on public.coach for all
    using (public.ho_ruolo(palestra_id, array['admin']::public.ruolo[]))
    with check (public.ho_ruolo(palestra_id, array['admin']::public.ruolo[]));

-- ESERCIZI: quelli comuni li vedono tutti, quelli di una palestra i suoi membri.
-- Li creano admin e coach (quelli comuni solo il super admin).
create policy "esercizi: lettura" on public.esercizi for select using (
    palestra_id is null or public.sono_membro(palestra_id)
);
create policy "esercizi: gestione" on public.esercizi for all
    using (case when palestra_id is null then public.sono_super()
                else public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]) end)
    with check (case when palestra_id is null then public.sono_super()
                     else public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]) end);

-- SCHEDE: l'atleta legge le sue; admin e coach (dei suoi atleti) le leggono e le scrivono.
create policy "schede: lettura" on public.schede for select using (public.seguo_atleta(palestra_id, atleta_id));
create policy "schede: gestione" on public.schede for all
    using (public.scrivo_per(palestra_id, atleta_id))
    with check (public.scrivo_per(palestra_id, atleta_id));

create policy "giorni: lettura" on public.giorni for select using (public.vedo_scheda(scheda_id));
create policy "giorni: gestione" on public.giorni for all
    using (public.scrivo_scheda(scheda_id)) with check (public.scrivo_scheda(scheda_id));

create policy "esercizi_giorno: lettura" on public.esercizi_giorno for select
    using (public.vedo_scheda(public.scheda_del_giorno(giorno_id)));
create policy "esercizi_giorno: gestione" on public.esercizi_giorno for all
    using (public.scrivo_scheda(public.scheda_del_giorno(giorno_id)))
    with check (public.scrivo_scheda(public.scheda_del_giorno(giorno_id)));

-- NOTE: le vedono l'atleta, il suo coach, l'admin e il super admin; tutti loro possono
-- scriverne di proprie; ognuno modifica e cancella solo le sue.
create policy "note: lettura" on public.note for select using (public.vedo_atleta(atleta_id));
create policy "note: scrivi" on public.note for insert
    with check (autore_id = auth.uid() and public.vedo_atleta(atleta_id));
create policy "note: modifica" on public.note for update
    using (autore_id = auth.uid() or public.sono_super())
    with check ((autore_id = auth.uid() or public.sono_super()) and public.vedo_atleta(atleta_id));
create policy "note: elimina" on public.note for delete using (autore_id = auth.uid() or public.sono_super());

-- ALLENAMENTI: li registra solo l'atleta, sulle proprie schede; li vedono anche coach, admin, super.
create policy "allenamenti: lettura" on public.allenamenti for select using (public.vedo_scheda(scheda_id));
create policy "allenamenti: registra" on public.allenamenti for all
    using (atleta_id = auth.uid())
    with check (atleta_id = auth.uid()
                and exists (select 1 from public.schede s where s.id = scheda_id and s.atleta_id = auth.uid()));

create policy "serie_svolte: lettura" on public.serie_svolte for select using (public.vedo_allenamento(allenamento_id));
create policy "serie_svolte: registra" on public.serie_svolte for all
    using (public.mio_allenamento(allenamento_id)) with check (public.mio_allenamento(allenamento_id));

-- MAPPA: la vedono tutti i membri, la modificano admin e coach.
create policy "sale: lettura" on public.sale for select using (public.sono_membro(palestra_id));
create policy "sale: gestione" on public.sale for all
    using (public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]))
    with check (public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]));

create policy "macchinari: lettura" on public.macchinari for select
    using (public.sono_membro(public.palestra_della_sala(sala_id)));
create policy "macchinari: gestione" on public.macchinari for all
    using (public.ho_ruolo(public.palestra_della_sala(sala_id), array['admin', 'coach']::public.ruolo[]))
    with check (public.ho_ruolo(public.palestra_della_sala(sala_id), array['admin', 'coach']::public.ruolo[]));

create policy "esercizi_macchinari: lettura" on public.esercizi_macchinari for select using (public.sono_membro(palestra_id));
create policy "esercizi_macchinari: gestione" on public.esercizi_macchinari for all
    using (public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]))
    with check (public.ho_ruolo(palestra_id, array['admin', 'coach']::public.ruolo[]));


-- ---------------------------------------------------------------------
-- Foto dei macchinari (Storage): cartella <palestra_id>/ nel bucket privato
-- "foto-macchinari". Le vedono i membri, le caricano admin e coach.
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public) values ('foto-macchinari', 'foto-macchinari', false)
on conflict (id) do nothing;

create function public.palestra_della_foto(percorso text) returns uuid
language sql immutable set search_path = '' as $$
    select case when split_part(percorso, '/', 1) ~ '^[0-9a-f-]{36}$'
                then split_part(percorso, '/', 1)::uuid end
$$;

create policy "foto: lettura" on storage.objects for select
    using (bucket_id = 'foto-macchinari' and public.sono_membro(public.palestra_della_foto(name)));
create policy "foto: carica" on storage.objects for insert
    with check (bucket_id = 'foto-macchinari'
                and public.ho_ruolo(public.palestra_della_foto(name), array['admin', 'coach']::public.ruolo[]));
create policy "foto: modifica" on storage.objects for update
    using (bucket_id = 'foto-macchinari'
           and public.ho_ruolo(public.palestra_della_foto(name), array['admin', 'coach']::public.ruolo[]));
create policy "foto: elimina" on storage.objects for delete
    using (bucket_id = 'foto-macchinari'
           and public.ho_ruolo(public.palestra_della_foto(name), array['admin', 'coach']::public.ruolo[]));
