-- Catalogo iniziale verificato sul sito il 12.11.2026 (verified_at non equivale a valid_from).
-- I pacchetti senza fascia oraria confermata hanno minutes = null: non sono vendibili come slot finché l'azienda non li configura.
insert into public.fleet_models(id,name,seats_max,license_required,requirement_note,bookable,booking_channel,external_url,fuel_note,source_url,source_lang,verified_at) values
 ('sup','Stand Up Paddle',1,false,'requisito da verificare',false,'phone',null,null,'https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('waterbike','Waterbike',2,false,'requisito da verificare',false,'phone',null,null,'https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('pedalo','Pedalò',6,false,'requisito da verificare; capienza 4-6 secondo l''unità',false,'regiondo','https://tinoleggiobarche.regiondo.it/noleggio-pedalo-247011',null,'https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('open5','Open 5',5,false,'senza patente; conducente maggiorenne (IT/EN ">18", DE/FR "da 18": conflitto da verificare)',false,'regiondo','https://tinoleggiobarche.regiondo.it/noleggio-barca-open-5-247017','carburante: inclusione non specificata','https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('open7','Open 7',7,false,'senza patente; conducente maggiorenne (conflitto 18 anni da verificare)',false,'regiondo','https://tinoleggiobarche.regiondo.it/noleggio-barca-open-7-new-247016','carburante: inclusione non specificata','https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('idea58','IDEA 58',7,true,'patente nautica; conducente maggiorenne (conflitto 18 anni da verificare)',false,'regiondo','https://tinoleggiobarche.regiondo.it/noleggio-barca-idea-58','benzina conteggiata a parte','https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('eden590','Eden 590',7,true,'patente nautica; conducente maggiorenne (conflitto 18 anni da verificare)',false,'regiondo','https://tinoleggiobarche.regiondo.it/noleggio-barca-marinello-590','benzina conteggiata a parte','https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('glastron','Glastron',7,true,'patente nautica; conducente maggiorenne (conflitto 18 anni da verificare)',false,'phone',null,'benzina conteggiata a parte','https://www.tinoleggiobarche.ch/','it','2026-11-12'),
 ('scooter','Scooter',2,false,'servizio su strada; licenza A1 valida; 2 caschi',false,'phone',null,null,'https://www.tinoleggiobarche.ch/','it','2026-11-12')
on conflict (id) do nothing;
insert into public.price_packages(model_id,code,label,minutes,price_cents,verified_at) values
 ('sup','h05','30 minuti',30,1200,'2026-11-12'),('sup','h1','1 ora',60,1800,'2026-11-12'),
 ('waterbike','h05','30 minuti',30,3000,'2026-11-12'),('waterbike','h1','1 ora',60,4500,'2026-11-12'),
 ('pedalo','h1','1 ora',60,2600,'2026-11-12'),
 ('open5','h1','1 ora',60,5000,'2026-11-12'),('open5','h2','2 ore',120,10000,'2026-11-12'),('open5','hd','mezza giornata',null,20000,'2026-11-12'),('open5','fd','giornata',null,40000,'2026-11-12'),
 ('open7','h1','1 ora',60,8000,'2026-11-12'),('open7','h2','2 ore',120,16000,'2026-11-12'),('open7','hd','mezza giornata',null,32000,'2026-11-12'),('open7','fd','giornata',null,60000,'2026-11-12'),
 ('idea58','hd','mezza giornata',null,35000,'2026-11-12'),('idea58','fd','giornata',null,50000,'2026-11-12'),
 ('eden590','hd','mezza giornata',null,39000,'2026-11-12'),('eden590','fd','giornata',null,59000,'2026-11-12'),
 ('glastron','hd','mezza giornata',null,55000,'2026-11-12'),('glastron','fd','giornata',null,75000,'2026-11-12'),
 ('scooter','hd','mezza giornata',null,5000,'2026-11-12'),('scooter','fd','giornata',null,8000,'2026-11-12'),('scooter','we','venerdì-domenica',null,16000,'2026-11-12')
on conflict (model_id,code) do nothing;
insert into public.policies(key,value,note) values
 ('hold_minutes','[15]','durata dell''opzione temporanea, proposta iniziale da confermare'),
 ('documents_before_confirmation','[true]','se true, senza patente approvata la prenotazione resta in attesa'),
 ('open_conflicts','["età minima a 18 anni esatti","carburante Open 5 e Open 7","requisiti SUP, Waterbike, Pedalò","orari e fasce di mezza giornata, giornata, ven-dom","cauzione, cancellazioni, rimborsi maltempo","canale WhatsApp aziendale"]','campi da completare dall''azienda: non riempire con prassi generiche')
on conflict (key) do nothing;
