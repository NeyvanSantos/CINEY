# Testes no emulador Android — 08/10/2026

O CiNey abriu e a navegação funcionou. A reprodução pelos fornecedores não foi
confirmada nesta execução; por isso, retomada no segundo salvo, créditos e avanço
automático de episódios permanecem sem validação de ponta a ponta.

## Ambiente e limites

- Emulador `CiNey_Android14`, ADB `emulator-5556`, Android 14 / API 34.
- 2 GB de RAM, 2 núcleos, tela 720 × 1600, renderização `software`.
- APK mobile publicado: CiNey **1.0.19**, código **21**.
- Android System WebView: `com.google.android.webview` **113.0.5672.136**.
- Interação por Python e ADB, com controles identificados na árvore de
  acessibilidade. Quando a árvore não expôs o controle HTML, o toque foi feito
  na posição observada na captura de tela, com o CiNey em primeiro plano.
- Os testes automatizados usam o checkout local. Ele já tinha uma alteração em
  `cast_dialog.dart` antes desta execução; o APK instalado não foi recompilado
  com essa alteração. Resultados de Cast no checkout não demonstram o
  comportamento desse APK em uma TV.

## Testes no dispositivo

| Fluxo | Resultado observado |
| --- | --- |
| Abrir o app | Tela inicial carregada, com catálogo e favoritos. |
| Buscar conteúdo | A sugestão “Thor” preencheu a busca e retornou 18 títulos. |
| Abrir detalhes | Filme e série abriram título, sinopse e opções de reprodução. |
| Escolher fornecedor | O seletor ofereceu SuperFlix e EmbedMovies. |
| SuperFlix / filme | Exibiu verificação humana do Cloudflare e mensagem de falha da verificação. Não foi automatizada a resolução do desafio. |
| EmbedMovies / filme | Abriu áudio Dublado e opções WatchPlay / Embed Play. Após selecionar WatchPlay, ficou no fundo do fornecedor; não houve confirmação de reprodução. |
| EmbedMovies / série | Abriu A Coroa Perfeita, T1:E1, com opção Legendado. Após acionar a seta do fornecedor, não houve confirmação de reprodução. |
| Próximo episódio | Não apareceu durante o carregamento/menu da série. Aparição nos créditos e transição no término não foram verificadas com vídeo ativo. |
| Preferência de retomada | Desligada pelo interruptor, permaneceu desligada após encerrar e reabrir o processo. Foi restaurada para ligada ao terminar o teste. |
| Sessão e histórico após reinício | O catálogo reabriu sem pedir novo login. Os títulos tentados continuaram em “Continuar Assistindo”; isso não confirma uma posição de vídeo salva. |
| Console de logs | Abriu, listou avisos dos fornecedores e filtrou erros. O filtro Erro mostrou zero entradas naquele momento. |
| Downloads | Tela abriu, mas os dois itens e os indicadores de armazenamento são dados fixos no código. Download e reprodução offline não foram comprovados. |

Nos avisos do app, ambos os fornecedores registraram
`-2 - net::ERR_NAME_NOT_RESOLVED (página principal: false)` e ausência de
confirmação de reprodução. Também houve bloqueio de redirecionamento externo.
O erro de DNS é de uma requisição secundária: o log não identifica sua URL e
não permite concluir que o servidor de vídeo inteiro está indisponível.

O histórico ganhou cartões mesmo sem confirmação de vídeo ativo. O filme
apareceu como “Em andamento”, sem minuto comprovado. Abrir novamente esse cartão
nestas condições não constitui um teste de retomada exata.

## Testes automatizados

| Execução | Resultado |
| --- | --- |
| Recorte Flutter: contas, preferências, histórico, continuidade, sessão e documentos do player | 75 passaram. |
| JavaScript: startup, ponte e observador de mídia | 33 passaram. |
| Suíte Flutter completa | 113 passaram; 7 falhas, incluindo um arquivo que não compilou. |
| `flutter analyze --no-pub` | 2 erros no teste do atualizador e 20 informações de depreciação de `withOpacity` no player. |

O recorte de 75 testes está incluído na suíte completa; suas contagens não devem
ser somadas. Os testes simulados verificam a lógica, mas não validam os
fornecedores remotos nem a TCL.

Falhas da suíte completa:

1. `app_updater_test.dart` não carrega: suas duas chamadas a
   `AppUpdater.selectLatestRelease` referenciam um método ausente.
2. Quatro testes em `cast_dialog_test.dart` falham com `WebViewPlatform.instance`
   não configurado no ambiente de teste, seguido de expectativas de widgets
   não encontrados: ausência de fonte, seleção de servidor, troca de servidor
   e layout em paisagem.
3. Dois testes em `native_cast_bridge_test.dart` divergem das expectativas:
   recusa de página embed com mídia na query e prioridade do formato do caminho
   sobre o formato sugerido pela query.

Comandos executados em `cinemax/`:

```powershell
flutter test --no-pub test/account_entry_test.dart test/accounts_test.dart test/accounts_repository_test.dart test/playback_preferences_test.dart test/player_episode_continuity_test.dart test/episode_sequence_test.dart test/watch_history_repository_test.dart test/embed_playback_session_test.dart test/embed_document_test.dart test/embed_navigation_test.dart
node --test test/embed_startup_test.cjs test/embed_media_observer_test.cjs test/embed_bridge_test.cjs
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
```

## Evidências

- [Verificação do SuperFlix](images/testes-android-2026-10-08/superflix-verificacao.png).
- [Menu do filme no EmbedMovies](images/testes-android-2026-10-08/embedmovies-filme-menu.png).
- [Menu da série no EmbedMovies](images/testes-android-2026-10-08/embedmovies-serie-menu.png).
- [Avisos no console do app](images/testes-android-2026-10-08/player-avisos.png).

As capturas de perfil com dados da conta não foram incluídas nas evidências do
repositório. Ferramentas temporárias e logs brutos ficaram fora do projeto.
O código do aplicativo e os arquivos de Cast não foram alterados nesta atividade.
Não foi gerado nem publicado um APK.
