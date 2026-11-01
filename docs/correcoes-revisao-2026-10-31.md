# Correções da nova revisão — 31/10/2026

Foram implementadas as correções dos seis problemas reproduzidos e dos dois riscos
de transporte da TV apresentados na nova revisão. As alterações anteriores foram
preservadas. Não houve commit, push, publicação, instalação de dependências ou
alteração de serviços remotos.

## Alterações e evidências

| Achado | Correção | Validação |
| --- | --- | --- |
| Título trocado após falha TMDB | IDs canônicos têm resposta própria ou erro; respostas de plugins com identidade diferente são recusadas. A busca de títulos locais exige correspondência única de título, tipo e ano | Teste offline que antes retornava outra série passou a retornar indisponibilidade; testes recusam outro filme e aceitam uma correspondência válida |
| Temporadas e episódios fabricados | IDs locais mapeados consultam o ID real; listas geradas artificialmente foram substituídas por consultas TMDB | Fixture fornece temporada 3/episódio 9 e confirma os endpoints consultados; temporada inexistente não gera episódios |
| Extensões removidas reaparecem | O provider de produção restaura a configuração de SharedPreferences; alterações são gravadas em ordem e o onboarding aguarda a gravação | Teste reconstrói gerenciadores e confirma restauração da seleção |
| Seleção vazia instala tudo | Lista vazia é uma escolha válida, com plugin ativo nulo | Testes confirmam configuração vazia em memória e após reinicialização |
| Cache repopulado por resposta antiga | Invalidação altera a geração, limpa requisições pendentes e impede que resultados antigos sejam armazenados | Regressão remove plugin durante consulta pendente e confirma ausência de detalhes no cache |
| Cast ignora fontes próprias | Detalhes/Assistir/Cast consultam PluginManager; respostas obsoletas e falhas de consulta são tratadas | Teste de interface transmite o MP4 do Internet Archive pelo contrato real de CastingSender |
| Navegador encerrado antes de um 401/403 tardio | Sessão do navegador fica retida enquanto o player nativo pode precisar dela, inclusive em provedores que não são SuperFlix | Teste de política de sessão falhou antes da correção e passou depois; Kotlin compilado |
| Frame arbitrário em origem desconhecida | FrameSelector exige origem registrada compatível, com validação de esquema, credenciais e porta | Três testes JVM verificam origem desconhecida, anúncio, barra final, porta padrão, credenciais e esquemas inválidos |

Os IDs locais permanecem nas identidades de detalhes, favoritos e histórico. Apenas
a consulta de metadados usa o ID canônico, evitando alterar chaves já existentes.
Para títulos locais sem correspondência remota segura, somente metadados locais
existentes podem ser apresentados; não são criados elenco, duração ou episódios.

O construtor de PluginManager aceita armazenamento injetado. O provider de produção
usa SharedPreferences; testes e instâncias sem armazenamento continuam em memória.

## Verificação executada

| Comando/escopo | Resultado |
| --- | --- |
| `flutter analyze --no-pub`: Mobile, TV e core | Zero issues |
| `flutter test --no-pub`: Mobile | 194 aprovados |
| `flutter test --no-pub`: core | 15 aprovados |
| `flutter test --no-pub`: host TV | 1 aprovado |
| Gradle JDK 17, offline, `:app:testDebugUnitTest` da TV | 10 aprovados, zero falhas/erros; Java e Kotlin compilados |
| Formatação Dart dos arquivos alterados | Aprovada |
| `git diff --check` | Aprovado |

Os testes de seleção vazia, cache e falha de identidade foram observados falhando
antes da correção. O teste de retenção de sessão da TV também foi executado com
falha antes da mudança. Os demais testes foram adicionados durante a implementação;
não são apresentados como ciclos RED/GREEN completos.

## Limites e pendência anterior

- Testes de widget/JVM não substituem testes em TV e celular físicos, especialmente
  cookies, 403 tardio, busca temporal e dispositivos Cast/Roku/DLNA.
- A permissão geral de HTTP continua sendo uma pendência anterior, com mitigação
  por domínio. Desativá-la globalmente exige separar/validar o transporte para IPs
  dinâmicos de LAN. Esta execução não alterou essa política nem declara esse risco
  eliminado. A revisão não comprovou uma substituição segura para todos os fluxos
  locais, portanto o bloqueio global não foi aplicado.
- A chave cliente TMDB não foi revogada ou migrada para um backend.

## Arquivos desta rodada

Produção: `plugin_manager.dart`, `builtin_plugins.dart`, `tmdb_service.dart`,
`details_screen.dart`, `onboarding_screen.dart`, `player_screen.dart`,
`TvPlaybackOptions.kt`, `BrowserMediaTransport.java` e novo `FrameSelector.java`.

Testes: novo `review_catalog_regressions_test.dart`, novo
`details_cast_sources_test.dart`, ajuste de fixture em `tv_series_navigation_test.dart`,
ajuste de `TvPlaybackOptionsTest.kt` e novo `FrameSelectorTest.kt`.

Habilidades AAS: systematic-debugging, flutter-expert, test-driven-development,
code-review-checklist e lint-and-validate. Instruções lidas dos SKILL.md locais;
a ferramenta nativa `skill` do OpenCode não está disponível nesta sessão.
