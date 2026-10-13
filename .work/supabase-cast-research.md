# Supabase Realtime: receiver CiNey TV

- Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization — salas privadas precisam de `RealtimeChannelConfig(private: true)` e políticas RLS `SELECT`/`INSERT` em `realtime.messages`; `realtime.topic()` expõe o tópico solicitado e `extension='broadcast'` distingue mensagens Broadcast. Supabase não persiste mensagens de Broadcast na tabela.
- Broadcast: https://supabase.com/docs/guides/realtime/broadcast — API Dart usa `channel.onBroadcast(event:, callback:)`, `channel.subscribe()` e `channel.sendBroadcastMessage(event:, payload:)`; transmissão pela conexão WebSocket após inscrição.
- Supabase changelog: https://supabase.com/changelog.md — em 2026-07-14 o schema `realtime` ficou protegido contra mudanças de objetos, mas políticas RLS em `realtime.messages` continuam permitidas; não emitir `ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY`.
- O desenho considerado usa tópico `ciney-cast:<auth.uid()>`, restringindo publicação e recepção ao usuário autenticado daquele tópico. O cliente TV recebe comandos efêmeros; o payload carrega IDs/metadata e nome do servidor, não URL de mídia direta.
