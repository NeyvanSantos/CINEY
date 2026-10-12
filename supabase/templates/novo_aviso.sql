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

-- ✏️ EDITE AQUI: título e texto do aviso
insert into public.app_notifications (title, body)
values (
  'TÍTULO AQUI',        -- 👈 coloque o título entre as aspas
  'TEXTO DO AVISO AQUI' -- 👈 coloque a mensagem entre as aspas
);

commit;
