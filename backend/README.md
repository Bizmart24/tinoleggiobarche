# TINO 2.0 · backend per Tinoleggio Barche

Stato al 12.11.2026. Questa cartella contiene ciò che serve per accendere le parti che richiedono un server.
Nell'app pubblicata TINO funziona già senza backend per chat, voce del browser, catalogo, meteo ed emergenza.

## Cosa è stato verificato e cosa no

| Parte | Stato |
|---|---|
| `001_tino_schema.sql` + `002_catalog_seed.sql` | Eseguiti e provati in un motore PostgreSQL locale con 30 verifiche (prenotazioni sovrapposte, doppio clic, conferma tardiva, permessi, versioni dei documenti). Non ancora eseguiti su un progetto Supabase reale. |
| `003_storage.sql` | Scritto, non provato: usa lo schema `storage` che esiste solo in Supabase. |
| `functions/tino-ai` | Scritta, non provata contro un fornitore AI. |
| Schermate dell'app per profilo, documenti, elenco utenti e verifica | Non ancora costruite: si collegano e si provano dopo la creazione del progetto. |
| Voce premium (trascrizione e sintesi lato server), pagamenti, API Regiondo | Non costruite: servono fornitore e credenziali. |

## Passi per creare il progetto

1. Crea un progetto gratuito su supabase.com (regione europea).
2. SQL Editor: esegui nell'ordine `001_tino_schema.sql`, `002_catalog_seed.sql`, `003_storage.sql`.
3. Authentication > Users: crea l'utente del gestore (e-mail e password).
4. SQL Editor: assegna il ruolo admin a quell'utente (il ruolo non si può assegnare dall'app):
   `insert into public.user_roles(user_id, role) select id, 'admin' from auth.users where email = 'EMAIL-DEL-GESTORE';`
5. Project Settings > API: copia "Project URL" e chiave "anon public" e comunicale a chi sviluppa l'app.
   Non comunicare mai la chiave "service_role".

## Decisioni che spettano al noleggio prima di vendere slot

Lo schema non inventa queste regole: finché mancano, il modello resta `bookable = false` e i pacchetti senza durata non sono vendibili.

- Esemplari reali per modello (`physical_units`): i conteggi del sito (11 SUP, 2 Waterbike) non sono inventario prenotabile.
- Fasce orarie di mezza giornata, giornata e ven-dom (`price_packages.minutes`).
- Durata dell'opzione (`policies.hold_minutes`, proposta iniziale 15 minuti).
- Documenti prima della conferma o prima della consegna (`policies.documents_before_confirmation`).
- Quanto può restare "in attesa" una prenotazione con documento da verificare prima di liberare il mezzo: oggi non ha scadenza automatica.
- Età minima a 18 anni esatti, carburante di Open 5 e Open 7, requisiti di SUP, Waterbike e Pedalò, cauzione, cancellazioni, rimborsi, orari.
- Tempi di conservazione ed eliminazione dei documenti.
- Fonte unica dell'inventario: se l'azienda usa Regiondo con API autorizzate, la disponibilità va letta da lì e questo inventario interno non va attivato per gli stessi mezzi.

## Funzioni del database

`calculate_quote`, `create_hold`, `prepare_confirmation`, `confirm_booking`, `admin_review_document`.
Ogni scrittura usa un identificativo di operazione: ripetere la stessa chiamata restituisce lo stesso esito senza doppioni.
La sovrapposizione sulla stessa unità è impedita da un vincolo del database, non dal codice dell'app.

## Collegare l'AI di TINO (facoltativo)

1. Distribuisci `functions/tino-ai` come Edge Function.
2. Imposta i segreti `TINO_AI_KEY` e `TINO_AI_MODEL`.
3. Comunica l'indirizzo della funzione: va inserito nella costante `TINO_AI_URL` dell'app.
Senza questi passi TINO continua a rispondere dal catalogo.
