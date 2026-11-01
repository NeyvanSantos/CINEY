# Correções da auditoria de 29/10/2026

Escopo aprovado: corrigir os achados da auditoria do commit 307c7a3, preservando
Mobile, TV, WebView e CastLite, sem publicar ou adicionar dependências.

## Decisões

- Corrigir os fluxos existentes com regressões direcionadas, sem substituir a arquitetura.
- Histórico pessoal: separar armazenamento por conta. O histórico legado não tem
  proprietário verificável e não será atribuído automaticamente a outra conta.
- Extensões: consultar e validar repositórios HTTPS. Apenas implementações
  disponíveis no aplicativo podem ser ativadas; scripts remotos não serão executados.
- Player: opções refletem capacidades reais. Áudio usa as faixas oferecidas pelo
  controlador; qualidade/legendas sem API de seleção exibem sua disponibilidade real.
- TV: manter o navegador durante a transferência interna, restaurar pausa e tratar
  cancelamento do seletor. A confirmação em hardware continua distinta dos testes locais.
- Segurança: limitar entradas do proxy sem alterar seu protocolo de transmissão.
- Validação: incluir núcleo, hosts, motor e testes nativos nos workflows. Publicação
  deve depender das verificações do mesmo commit.

## Premissas

Manter desempenho em TVs com pouca memória, limites explícitos para trabalho de
rede, isolamento entre contas e compatibilidade com as fontes existentes. Mudanças
em serviços remotos, revogação de chaves e novos APKs não fazem parte desta execução.

## Resultado em 30/10/2026

Foram implementadas correções para 16 achados; o achado de HTTP geral recebeu
mitigação parcial. Isso não equivale a afirmar que todos os riscos foram eliminados.
Não houve commit, push, tag, publicação, instalação de novas dependências ou mudança
em serviços remotos. Os comandos Gradle compilaram código para testes, sem gerar
uma release distribuível.

| Achado | Alteração | Evidência/limite |
| --- | --- | --- |
| 1. Fallback Mobile ignora servidor anterior | Tentativas circulares, sem repetir fontes, e espera limitada ao encerrar controlador com erro | Regressão inicia na última fonte, provoca erro e confirma abertura da primeira |
| 2. Controles fictícios | Áudio consulta e seleciona faixas reais; qualidade oferece fontes reais; legendas explicam a capacidade do provedor | Testes verificam chamada de seleção de áudio e ausência de resolução inventada. Não foi criado suporte a legendas que o controlador não oferece |
| 3. WebView interrompida no handoff TV | Mantém transporte enquanto a operação nativa está pendente | Teste de pausa durante handoff confirma que `about:blank` não é carregado; teste de background normal permanece válido |
| 4. Cancelar fontes deixa TV vazia | Restaura provedor ao cancelar modal após retorno nativo | Regressão de widget confirma recriação do `TvEmbedPlayer` |
| 5. TV retoma reprodução que estava pausada | Guarda/restaura `playWhenReady` junto com posição e estado Android | Kotlin compilado e suíte nativa aprovada; ciclo completo de Activity ainda exige dispositivo |
| 6. Instalar extensão só mostra mensagem | Aciona `installPlugin`; implementações ausentes recebem explicação, sem sucesso falso | Teste toca em Instalar e confirma extensão no gerenciador |
| 7. Repositório ignora URL | Catálogo local explícito; leitura de manifestos HTTPS, sem redirecionamentos, limite de tamanho/quantidade, cancelamento e prazo total | Testes verificam URLs efetivamente consultadas, manifesto relativo, URL inválida e resposta obsoleta |
| 8. Plugin ativo após remover último | Limpa explicitamente o ativo e trata coleção vazia | Regressão remove todos e tenta selecionar um ID inexistente |
| 9. Fontes próprias ignoradas | Consulta implementação do plugin antes do resolvedor comum | Regressão confirma MP4 do Internet Archive, sem substituição por embed |
| 10. Homônimos removidos | Deduplicação usa identidade do item, tipo e plugin | Regressão preserva três obras distintas com mesmo título |
| 11. Busca aceita resposta antiga | Invalida requisição no momento da edição, antes do debounce | Teste conclui consulta antiga enquanto nova está pendente |
| 12. Falhas silenciosas TMDB | Logs com tipo de erro e stack, sem URL/chave; falha de busca sem fallback útil apresenta erro e nova tentativa | Testes de erro/repetição da busca e coleções aprovados. Catálogos com fallback ainda podem apresentar conteúdo local |
| 13. HTTP global | Remove CIDRs inválidos e exige TLS para domínios públicos conhecidos | **Parcial:** `base-config` continua permissiva para IPs dinâmicos de LAN, Roku/DLNA e mídia local. Hosts públicos não listados continuam permitidos |
| 14. Histórico entre contas | Chave de armazenamento inclui ID da conta; provider acompanha sessão | Teste alterna Alice/Bob/Alice e confirma isolamento. Histórico legado sem dono não é migrado automaticamente |
| 15. Proxy LAN sem limites | Bind no IPv4 privado escolhido; 8 workers e fila de 16; deadline de 5 s; linha de 8 KiB, cabeçalhos de 32 KiB/64 entradas; fecha sockets no encerramento | Cinco regressões do parser, mais suíte CastLite. Não é proteção contra toda negação de serviço da rede local |
| 16. CI/release sem cobertura | CI inclui core, TV, engine e Kotlin; releases dependem da validação e fazem checkout do SHA testado | `actionlint` aprovado; comandos locais aprovados. Workflow remoto não disparado |
| 17. Testes bloqueados | Teste com IO real deixa de usar relógio de widget; cache nativo obsoleto regenerado; caminho Windows de build restaurado | Suítes Flutter voltaram a executar; builds nativos offline aprovados |

## Validação executada

| Verificação | Resultado |
| --- | --- |
| `flutter analyze --no-pub` em `cinemax`, `cinemax_tv`, `packages/ciney_core` | Zero issues nos três |
| `flutter test --no-pub` em Mobile | 192 aprovados na suíte completa; teste adicional de ativação de extensão aprovado separadamente: 193 testes distintos |
| `flutter test --no-pub` no core | 8 aprovados |
| `flutter test --no-pub` no host TV | 1 aprovado |
| Gradle offline `:castlite_engine:testDebugUnitTest` | 86 aprovados, zero falhas/erros |
| Gradle offline TV `:app:testDebugUnitTest` | 7 aprovados, zero falhas/erros |
| Seis arquivos Node de embed/bridge/startup/TV | 59 aprovados |
| `node --test supabase/tests/notification_policy.test.ts` | 13 aprovados |
| Player engine: unitários e integração de mídia autorizada | 10 aprovados |
| Player engine: `tsc --noEmit` | Aprovado |
| `actionlint` em CI e ambos os workflows de release | Aprovado |
| `git diff --check` | Aprovado |

As regressões de fallback, handoff TV, plugins e isolamento de histórico foram
observadas falhando antes das respectivas correções. Os demais testes novos foram
adicionados durante/depois da implementação; não são apresentados como ciclos
RED/GREEN quando isso não ocorreu.

O teste antigo de repositório esperava a URL remota fictícia. Foi atualizado para
verificar o catálogo local e a correspondência com implementações reais; os testes
novos cobrem o carregamento remoto separadamente.

No Windows, Gradle foi executado com JDK 17 já instalado. O mapeamento `X:` para a
raiz deste repositório foi restaurado porque os arquivos gerados referenciavam esse
caminho. O cache antigo de hooks foi preservado em diretório ignorado de backup.
Nenhuma dependência foi baixada pelos comandos Gradle (`--offline`).

## Limitações e próximos passos

1. **HTTP geral:** para desabilitar globalmente sem perder Roku/DLNA e servidores
   locais, é necessário separar o transporte LAN e aplicar nele validação explícita
   de endereço. A configuração Android não representa redes CIDR. A mitigação atual
   protege os domínios listados, mas não resolve integralmente esse achado.
   Referência: [Network security configuration](https://developer.android.com/privacy-and-security/security-config).
2. **Hardware:** validar Mobile/TV físicos, retorno de segundo plano com pausa,
   codecs, legendas do provedor, cookies/403 tardios e transmissão Roku/DLNA/Cast.
   Nenhum Android estava conectado; testes de widget/JVM não comprovam esses cenários.
3. **Chave TMDB:** a credencial cliente anteriormente identificada não foi revogada.
   Mover apenas para `dart-define` não a torna secreta no APK. Rotação e eventual
   intermediação por backend precisam de configuração do serviço e validação de
   disponibilidade do catálogo; não foram efetuadas nesta execução.
4. **CI remoto:** validar execução em branch de trabalho antes de publicar. As
   dependências entre jobs e o SHA foram verificados localmente por lint/leitura;
   não foi feito push para testar a infraestrutura GitHub.
5. **Avisos nativos:** há deprecações Android/Gradle preexistentes; não impediram
   compilação/testes. Não foi feita atualização ampla de Gradle ou dos plugins.

## Arquivos e habilidades

Arquivos de produção alterados: os três workflows; `LocalMediaProxy.kt` e novo
`ProxyRequestReader.kt`; os dois `network_security_config.xml`;
`NativeTvPlayerActivity.kt`; no core, `extensions_screen.dart`, `player_screen.dart`,
`tv_cast_service.dart`, `watch_history_repository.dart`, `tv_embed_player.dart`,
`search_screen.dart`, `plugin_manager.dart`, `repository_manager.dart` e
`tmdb_service.dart`. Também foram adicionados/atualizados os testes correspondentes
em `cinemax/test`, `packages/ciney_core/test` e `CastLite/.../src/test`, além deste relatório.

Habilidades AAS aplicadas: `systematic-debugging`, `flutter-expert`,
`test-driven-development`, `code-review-checklist`, `lint-and-validate`,
`api-contract-testing`, `auth-implementation-patterns`, `secrets-management`,
`github-actions-templates`, `brainstorming` e `supabase` para a validação relacionada.
As instruções foram lidas dos arquivos locais; esta sessão não disponibiliza a
ferramenta nativa `skill` do OpenCode.
