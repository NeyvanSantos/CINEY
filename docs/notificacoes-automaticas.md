# Notificações automáticas do CiNey

Implementação de 15/10/2026. O recebimento push pertence ao host **mobile**;
`ciney_core` expõe apenas os pontos de integração. A TV continua com avisos
dentro do aplicativo e sem dependências Firebase.

## Estado da configuração

- Firebase: `ciney-594e2`, aplicativo oficial `com.ciney.app` e cliente de teste
  `com.ciney.app.castlite_test`. O `google-services.json` contém identificadores
  de cliente, não a chave privada de administração.
- Supabase: `fekultszwaxbzejdfluq`. As funções `notification-worker` e
  `notification-self-test` estão implantadas; as duas migrações desta integração
  foram aplicadas e registradas individualmente.
- `FIREBASE_SERVICE_ACCOUNT` permanece somente nos segredos das Edge Functions.
  A verificação `health` autenticou no Google e passou pelo FCM com
  `validate_only: true`, sem entregar mensagem.
- **`NOTIFICATIONS_MODE=live`**, ativado em 15/10/2026 após o usuário confirmar
  o recebimento do aviso de teste. A automação consulta as fontes e entrega
  os eventos aos aparelhos registrados, respeitando as preferências da conta.
- Integração incluída na versão mobile 1.0.41. O aparelho será registrado
  depois de atualizar, entrar na conta e permitir notificações. A automação
  geral está ligada; o botão de teste individual continua disponível.

## Comportamento

| Evento | Origem | Frequência / destino |
| --- | --- | --- |
| Novidades do catálogo | Mesmas consultas TMDB das categorias do app | Consulta a cada 6 horas; um resumo por dia, a partir das 18h de Brasília |
| Episódios de favoritos | `last_episode_to_air` de títulos TMDB favoritados | Consulta horária, até 20 séries diferentes por rodada, com cursor |
| Novidades do aplicativo | GitHub Releases oficial, tag mobile estável e APK correspondente já enviado | Consulta horária; um aviso por nova versão |
| Teste | Ação do usuário em Perfil → Notificações | Somente o aparelho da conta autenticada; uma tentativa por minuto |

A primeira leitura de cada fonte apenas cria uma referência; ela não avisa
sobre todo o conteúdo antigo. A consulta do catálogo cobre as listagens
selecionadas, não todos os títulos existentes no TMDB. Metadados de estreia
não comprovam que uma fonte de vídeo já reproduz o conteúdo: os textos dizem
“novidades do catálogo” e “episódio anunciado”.

O perfil permite desligar todos os avisos ou escolher filmes, séries, animes,
doramas, episódios e atualizações do aplicativo. A permissão do Android também
precisa estar ativa. Tocar no aviso abre somente destinos conhecidos: catálogo,
detalhes do título, preferências ou verificação de atualização. Nenhuma URL ou
rota arbitrária recebida por push é executada; a entrada pela conta permanece
obrigatória.

## Segurança e entrega

- Preferências e identificadores FCM têm RLS por usuário. Clientes não podem
  consultar fila, catálogo interno, checkpoints ou RPCs do servidor.
- O worker exige `x-ciney-job-key`; o teste verifica a sessão com o servidor
  Auth e aceita apenas um aparelho já registrado pela própria conta.
- O mobile usa os registros por Firebase Installation ID da versão atual do
  SDK. Ao mudar de conta, remove o registro e troca a instalação Firebase.
  Ao sair, tenta remover também o vínculo no servidor e limpa avisos locais.
- A fila usa uma chave única por aparelho/evento, reserva temporária, cinco
  tentativas, expiração em 24 horas e nova verificação das preferências antes
  de enviar. Um identificador explicitamente `UNREGISTERED` é removido.
- Não existe garantia de entrega exatamente uma vez: uma interrupção entre a
  aceitação pelo FCM e a confirmação no banco pode gerar nova tentativa.
  O mesmo evento mantém a mesma tag de notificação no Android.
- A entrega depende de rede, serviços Google e permissão do aparelho. Um app
  interrompido à força pelo Android precisa ser aberto novamente.

## Agendamento e operação

O Cron consulta a automação a cada 15 minutos e tenta entregar até 20 avisos
por minuto. A limpeza diária remove filas com mais de 7 dias, registros do
catálogo com mais de 120 dias e aparelhos sem atualização há 90 dias.
O segredo de chamada fica no Vault como `ciney_notification_job_key`, sem
aparecer no SQL versionado dos agendamentos.

Variáveis da Edge Function:

| Nome | Uso |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT` | JSON privado da conta de serviço Firebase, salvo pelo administrador |
| `NOTIFICATIONS_JOB_SECRET` | Credencial aleatória compartilhada com o Vault |
| `TMDB_API_KEY` | Credencial da consulta do catálogo |
| `NOTIFICATIONS_MODE` | `off`, `test` ou `live`; padrão `off` |
| `PUSH_TEST_USER_ID` | Conta única permitida para automação no modo `test` |

Os segredos de desenvolvimento estão em arquivo ignorado em
`.work/dependency-separation/notifications.env`; não copiar esse arquivo para
Git, APK, documentação pública ou conversa. Os arquivos JSON privados de
Admin SDK também não pertencem ao aplicativo.

Para testar um aparelho, entrar na conta, permitir as notificações e usar
**Enviar aviso de teste**. Esse botão envia somente para o próprio aparelho
e também funciona quando os disparos gerais estão desligados. O usuário
confirmou o recebimento e autorizou explicitamente a ativação para todos.

## Validações

- 173 testes Flutter passaram, incluindo os destinos permitidos para push.
- 13 testes de servidor passaram, incluindo autenticação, preferências,
  leitura inicial silenciosa, isolamento do teste e tentativas de entrega.
- SQL executado em PostgreSQL descartável: isolamento entre contas, bloqueio
  de troca de dono do aparelho, fila, reserva e limite de teste passaram.
- `deno check` passou para as duas Edge Functions.
- Análise Flutter do mobile e da TV passou sem problemas.
- Processamento de `google-services.json` e compilação Kotlin/Java do Android
  passaram (`BUILD SUCCESSFUL`), sem gerar ou publicar APK.
- No servidor, a leitura inicial registrou 31 itens e deixou a fila vazia;
  `health` retornou `configured: true`, `mode: off`, `validation_only: true`.
- Os advisors não apontaram avisos nas novas tabelas/funções de notificações;
  existem avisos de outros objetos e configurações fora desta integração.
- Após a publicação da 1.0.41, o usuário confirmou o recebimento do aviso de
  teste no aparelho. A ativação retornou `configured: true`, `mode: live`;
  uma execução real do worker confirmou `sent: 0`, `claimed: 0`, `mode: live`,
  sem eventos pendentes naquele momento. Os três agendamentos estavam ativos.

Comandos de teste:

```powershell
node --experimental-strip-types --test supabase/tests/notification_policy.test.ts
npx --yes deno@2.9.6 check supabase/functions/notification-worker/index.ts supabase/functions/notification-self-test/index.ts
./scripts/test_accounts_database.ps1
cd cinemax
flutter test
flutter analyze
```

Referências oficiais:
[recebimento Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[registro FCM](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[API de envio](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages),
[Supabase Cron](https://supabase.com/docs/guides/functions/schedule-functions).
