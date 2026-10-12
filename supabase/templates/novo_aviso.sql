-- ============================================================
--  CiNey — Publicar aviso para os clientes
--
--  COMO USAR:
--  1. Abra o Supabase Dashboard → SQL Editor → New query
--  2. Cole este conteúdo
--  3. Troque APENAS os dois textos abaixo (entre as aspas)
--  4. Clique em Run
-- ============================================================

begin;

-- Desativa os avisos antigos (o app mostra só o mais recente)
update public.app_notifications set is_active = false where is_active;

-- ✏️ EDITE AQUI: APAGUE os textos de exemplo e escreva os seus NO MESMO LUGAR,
--    sempre entre aspas simples. Não escreva nada depois de "--".
--    Exemplo: values ('Novidade!', 'Nova coleção no catálogo.');
insert into public.app_notifications (title, body)
values (
  'TÍTULO AQUI',
  'TEXTO DO AVISO AQUI'
);

commit;
