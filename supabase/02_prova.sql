-- =====================================================================
-- Ghisa · dati di prova e controllo dei permessi
-- Da eseguire DOPO 01_schema.sql, solo su un progetto di prova.
-- Crea 6 utenti finti, poi prova ogni ruolo e mostra una tabella
-- controllo / atteso / risultato. Tutte le righe devono avere ok = true.
-- I tentativi di scrittura vengono annullati: non lasciano dati.
-- =====================================================================

-- Utenti finti (la riga in "utenti" si crea da sola grazie al trigger).
insert into auth.users (id, email, raw_user_meta_data, aud, role) values
    ('00000000-0000-0000-0000-000000000001', 'simone@prova.local', '{"nome":"Simone"}', 'authenticated', 'authenticated'),
    ('00000000-0000-0000-0000-000000000002', 'mario@prova.local',  '{"nome":"Mario"}',  'authenticated', 'authenticated'),
    ('00000000-0000-0000-0000-000000000003', 'luca@prova.local',   '{"nome":"Luca"}',   'authenticated', 'authenticated'),
    ('00000000-0000-0000-0000-000000000004', 'anna@prova.local',   '{"nome":"Anna"}',   'authenticated', 'authenticated'),
    ('00000000-0000-0000-0000-000000000005', 'paolo@prova.local',  '{"nome":"Paolo"}',  'authenticated', 'authenticated'),
    ('00000000-0000-0000-0000-000000000006', 'giulia@prova.local', '{"nome":"Giulia"}', 'authenticated', 'authenticated');

update public.utenti set super_admin = true where id = '00000000-0000-0000-0000-000000000001';   -- Simone

insert into public.palestre (id, nome, proprietario) values
    ('10000000-0000-0000-0000-000000000001', 'Palestra Ferro',   '00000000-0000-0000-0000-000000000002'),
    ('10000000-0000-0000-0000-000000000002', 'Palestra Acciaio', '00000000-0000-0000-0000-000000000006');

insert into public.membri (palestra_id, utente_id, ruolo) values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'admin'),   -- Mario
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'coach'),   -- Luca
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'atleta'),  -- Anna
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'atleta'),  -- Paolo
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006', 'admin');   -- Giulia

-- Luca segue Anna (non Paolo).
insert into public.coach values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004');

insert into public.esercizi (id, palestra_id, nome, gruppo) values
    ('20000000-0000-0000-0000-000000000001', null, 'Panca piana', 'Petto'),
    ('20000000-0000-0000-0000-000000000002', null, 'Lat machine', 'Dorso');

insert into public.schede (id, palestra_id, atleta_id, autore_id, titolo) values
    ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'Scheda Anna'),
    ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 'Scheda Paolo');

insert into public.giorni (id, scheda_id, ordine, nome) values
    ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, 'A'),
    ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 1, 'A');

insert into public.esercizi_giorno (id, giorno_id, esercizio_id, ordine, serie, ripetizioni) values
    ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1, 4, '8-10'),
    ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 1, 3, '12');

insert into public.allenamenti (id, atleta_id, scheda_id, giorno_id) values
    ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004',
     '30000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001');

insert into public.serie_svolte (allenamento_id, esercizio_giorno_id, numero, peso, ripetizioni) values
    ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1, 40, 10);

-- Nota personale di Anna sulla Panca piana (resta anche con schede nuove).
insert into public.note (atleta_id, esercizio_id, autore_id, testo) values
    ('00000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000004', 'Male alla spalla, scendere piano');

insert into public.sale (id, palestra_id, nome) values
    ('70000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Sala pesi');
insert into public.macchinari (id, sala_id, nome) values
    ('80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'Panca regolabile');


-- ---------------------------------------------------------------------
-- Strumenti di prova: eseguono una query "come se" fosse quell'utente.
-- ---------------------------------------------------------------------

-- Quante righe vede l'utente con questa query?
create function pg_temp.vede(utente uuid, query text) returns bigint language plpgsql as $$
declare n bigint;
begin
    perform set_config('request.jwt.claims', json_build_object('sub', utente, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    execute 'select count(*) from (' || query || ') q' into n;
    execute 'reset role';
    return n;
end $$;

-- L'utente riesce a fare questa scrittura? (viene sempre annullata)
create function pg_temp.puo(utente uuid, comando text) returns boolean language plpgsql as $$
declare n bigint;
begin
    begin
        perform set_config('request.jwt.claims', json_build_object('sub', utente, 'role', 'authenticated')::text, true);
        execute 'set local role authenticated';
        execute comando;
        get diagnostics n = row_count;
        raise exception using errcode = 'P0001', message = 'annulla', detail = n::text;
    exception
        when sqlstate 'P0001' then
            get stacked diagnostics comando = pg_exception_detail;
            n := comando::bigint;
        when others then
            n := 0;   -- rifiutato dalle regole
    end;
    execute 'reset role';
    return n > 0;
end $$;


-- ---------------------------------------------------------------------
-- I controlli
-- ---------------------------------------------------------------------
with
u (simone, mario, luca, anna, paolo, giulia) as (values (
    '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid, '00000000-0000-0000-0000-000000000004'::uuid,
    '00000000-0000-0000-0000-000000000005'::uuid, '00000000-0000-0000-0000-000000000006'::uuid)),
controlli (n, controllo, atteso, risultato) as (
    select t.* from u, lateral (values
    -- Atleta
    ( 1, 'Anna (atleta) vede solo la sua scheda',             '1',     pg_temp.vede(anna, 'select * from public.schede')::text),
    ( 2, 'Anna vede i suoi allenamenti',                      '1',     pg_temp.vede(anna, 'select * from public.allenamenti')::text),
    ( 3, 'Anna vede le persone: sé, coach e admin (non Paolo)', '3',   pg_temp.vede(anna, 'select * from public.utenti')::text),
    ( 4, 'Anna vede la mappa',                                '1',     pg_temp.vede(anna, 'select * from public.macchinari')::text),
    ( 5, 'Anna NON cambia la sua scheda',                     'false', pg_temp.puo(anna, $q$update public.schede set titolo = 'x' where id = '30000000-0000-0000-0000-000000000001'$q$)::text),
    ( 6, 'Anna NON cambia gli esercizi della scheda',         'false', pg_temp.puo(anna, $q$update public.esercizi_giorno set serie = 9$q$)::text),
    ( 7, 'Anna registra un allenamento sulla sua scheda',     'true',  pg_temp.puo(anna, $q$insert into public.allenamenti (atleta_id, scheda_id) values ('00000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001')$q$)::text),
    ( 8, 'Anna registra pesi e ripetizioni',                  'true',  pg_temp.puo(anna, $q$insert into public.serie_svolte (allenamento_id, numero, peso, ripetizioni) values ('60000000-0000-0000-0000-000000000001', 2, 42.5, 8)$q$)::text),
    ( 9, 'Anna NON registra sulla scheda di Paolo',           'false', pg_temp.puo(anna, $q$insert into public.allenamenti (atleta_id, scheda_id) values ('00000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002')$q$)::text),
    (10, 'Anna scrive una nota sulla Lat machine',            'true',  pg_temp.puo(anna, $q$insert into public.note (atleta_id, esercizio_id, autore_id, testo) values ('00000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', 'sedile 4')$q$)::text),
    (11, 'Anna NON si fa super admin',                        'false', pg_temp.puo(anna, $q$update public.utenti set super_admin = true where id = '00000000-0000-0000-0000-000000000004'$q$)::text),
    (12, 'Anna NON modifica la mappa',                        'false', pg_temp.puo(anna, $q$update public.macchinari set nome = 'x'$q$)::text),
    -- Coach
    (13, 'Luca (coach) vede solo la scheda di Anna',          '1',     pg_temp.vede(luca, 'select * from public.schede')::text),
    (14, 'Luca vede gli allenamenti di Anna',                 '1',     pg_temp.vede(luca, 'select * from public.serie_svolte')::text),
    (15, 'Luca crea una scheda per Anna',                     'true',  pg_temp.puo(luca, $q$insert into public.schede (palestra_id, atleta_id, autore_id, titolo) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'Nuova')$q$)::text),
    (16, 'Luca NON crea schede per Paolo (non lo segue)',     'false', pg_temp.puo(luca, $q$insert into public.schede (palestra_id, atleta_id, autore_id, titolo) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 'Nuova')$q$)::text),
    (17, 'Luca cambia gli esercizi della scheda di Anna',     'true',  pg_temp.puo(luca, $q$update public.esercizi_giorno set serie = 5 where id = '50000000-0000-0000-0000-000000000001'$q$)::text),
    (18, 'Luca NON registra allenamenti al posto di Anna',    'false', pg_temp.puo(luca, $q$insert into public.allenamenti (atleta_id, scheda_id) values ('00000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001')$q$)::text),
    (19, 'Luca NON aggiunge membri',                          'false', pg_temp.puo(luca, $q$insert into public.membri (palestra_id, utente_id, ruolo) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'atleta')$q$)::text),
    (20, 'Luca modifica la mappa',                            'true',  pg_temp.puo(luca, $q$update public.macchinari set nome = 'Panca 2'$q$)::text),
    -- Admin
    (21, 'Mario (admin) vede tutte le schede della palestra', '2',     pg_temp.vede(mario, 'select * from public.schede')::text),
    (22, 'Mario crea una scheda per Paolo',                   'true',  pg_temp.puo(mario, $q$insert into public.schede (palestra_id, atleta_id, autore_id, titolo) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 'Nuova')$q$)::text),
    (23, 'Mario assegna un atleta a Luca',                    'true',  pg_temp.puo(mario, $q$insert into public.coach values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005')$q$)::text),
    (24, 'Mario aggiunge un membro',                          'true',  pg_temp.puo(mario, $q$insert into public.membri (palestra_id, utente_id, ruolo) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 'atleta')$q$)::text),
    (25, 'Mario NON crea palestre',                           'false', pg_temp.puo(mario, $q$insert into public.palestre (nome) values ('Altra')$q$)::text),
    -- Altra palestra
    (26, 'Giulia (admin di un''altra palestra) non vede schede', '0',  pg_temp.vede(giulia, 'select * from public.schede')::text),
    (27, 'Giulia vede solo la sua palestra',                  '1',     pg_temp.vede(giulia, 'select * from public.palestre')::text),
    (28, 'Giulia NON vede la mappa della Palestra Ferro',     '0',     pg_temp.vede(giulia, 'select * from public.macchinari')::text),
    -- Super admin
    (29, 'Simone (super admin) vede tutte le palestre',       '2',     pg_temp.vede(simone, 'select * from public.palestre')::text),
    (30, 'Simone vede tutte le schede',                       '2',     pg_temp.vede(simone, 'select * from public.schede')::text),
    (31, 'Simone crea una palestra',                          'true',  pg_temp.puo(simone, $q$insert into public.palestre (nome) values ('Nuova')$q$)::text),
    -- Note personali
    (32, 'Luca (suo coach) legge la nota di Anna',            '1',     pg_temp.vede(luca, 'select * from public.note')::text),
    (33, 'Luca aggiunge una sua nota per Anna',               'true',  pg_temp.puo(luca, $q$insert into public.note (atleta_id, esercizio_id, autore_id, testo) values ('00000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'ok, carico -10%')$q$)::text),
    (34, 'Luca NON modifica la nota scritta da Anna',         'false', pg_temp.puo(luca, $q$update public.note set testo = 'x'$q$)::text),
    (35, 'Anna modifica la sua nota',                         'true',  pg_temp.puo(anna, $q$update public.note set testo = 'Spalla meglio'$q$)::text),
    (36, 'Mario (admin) legge la nota di Anna',               '1',     pg_temp.vede(mario, 'select * from public.note')::text),
    (37, 'Paolo (altro atleta) NON legge le note di Anna',    '0',     pg_temp.vede(paolo, 'select * from public.note')::text),
    (38, 'Giulia (altra palestra) NON legge le note di Anna', '0',     pg_temp.vede(giulia, 'select * from public.note')::text),
    (39, 'Anna NON scrive note a nome di Paolo',              'false', pg_temp.puo(anna, $q$insert into public.note (atleta_id, esercizio_id, autore_id, testo) values ('00000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'x')$q$)::text)
    ) as t (n, controllo, atteso, risultato)
)
select n, controllo, atteso, risultato, atteso = risultato as ok
from controlli order by n;
