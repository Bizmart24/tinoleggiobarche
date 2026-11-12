-- Archivio privato dei documenti. Percorso dei file: <id utente>/<id documento>/<versione>.<estensione>
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('documents','documents',false,20971520,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;
create policy "documenti: carica il proprietario" on storage.objects for insert to authenticated
  with check (bucket_id='documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "documenti: legge proprietario o admin" on storage.objects for select to authenticated
  using (bucket_id='documents' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
-- Nessuna regola per anon: nessun URL pubblico. L'app usa solo link firmati a scadenza breve.
