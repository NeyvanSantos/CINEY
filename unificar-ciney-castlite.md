# Unificar CiNey e CastLite

Data: 14/10/2026. Tipo: MOBILE — Flutter com implementação Android/Kotlin.
Status: integração implementada, APK local compilado e validação automatizada concluída; teste físico pendente. Distribuição pública não autorizada.

## Objetivo e decisão

Entregar um único aplicativo CiNey, mantendo `com.ciney.app`, catálogo, contas, player e atualizador. Incorporar o CastLite como plugin Flutter local com biblioteca Android. Na primeira entrega, reutilizar sua tela nativa de navegação/transmissão dentro do mesmo aplicativo; uniformizar os controles em Flutter depois da validação. O fluxo será: título/episódio → servidor → tela interna de transmissão → dispositivo → reprodução e controle remoto.

Este plano desenvolve a opção B de [PLAN-ciney-castlite-bridge.md](docs/PLAN-ciney-castlite-bridge.md). A ponte externa prevista na opção A deixa de ser a solução para o requisito de aplicativo único. O projeto CastLite original permanece como referência durante a migração; o motor terá uma única implementação mantida após a transição.

## Evidência encontrada no código

- `cinemax/lib/features/player/services/castlite_bridge_service.dart` atualmente abre `castlite://play` por `url_launcher`; detalhes, seletor de servidores e player já possuem chamadas em desenvolvimento. Essas alterações locais devem ser preservadas e adaptadas.
- `CastLite/CastLite/app` contém `VideoDetector`, observação de frames, `FrameMediaTransport`, `LocalMediaProxy`, `HlsPlaylist`, `CastingService`, controle remoto e implementações de `CastTarget` para Google Cast, DLNA e Roku. Existência de código não comprova funcionamento de cada protocolo.
- A `MainActivity` nativa concentra navegador, detecção e seleção de dispositivos; o controle remoto ainda possui referência à Activity. O serviço já retém recursos durante a transmissão, portanto a migração precisa preservar e revisar essa transferência de responsabilidade.
- A ponte envia posição e pôster, mas o receptor atual não aplica todos esses dados: `incomingResumePositionMs` é armazenado e não consumido. Headers da `StreamSource` também precisam entrar no contrato interno.
- Os hosts usam versões diferentes de AGP/Kotlin/Gradle. A compilação confirmou que o transporte Jetty exige API 26. O usuário escolheu Android 8 ou superior com motor completo; o mínimo foi alinhado no plugin e nos dois hosts.
- `cinemax_tv` consome `cinemax` por `path: ../cinemax`; verificar o registro transitivo do plugin e preservar seu fluxo próprio de reprodução/recepção.

## Arquitetura, tecnologias e arquivos

Reutilizar Flutter/Riverpod e Kotlin existentes. O plugin será uma Android Library, sem `applicationId` próprio. `MethodChannel` envia comandos e `EventChannel` devolve estados; um retrato consultável da sessão permite recuperar a interface após voltar à tela. Não é necessário reescrever HLS ou o relay em Dart.

Implementação: o plugin referencia pelo Gradle as fontes, recursos e testes em `CastLite/CastLite/app/src`, preservando uma única cópia do motor e o host independente. A Activity nativa mantém seu nome `com.example.castlite.MainActivity` e é privada no manifesto do CiNey. Detalhes da integração em [integracao-castlite.md](docs/integracao-castlite.md).

```text
cinemax/packages/castlite_engine/
  pubspec.yaml                         # plugin Android local
  lib/                                 # API Dart e contrato de sessão
  android/src/main/                    # Kotlin, res, assets e manifesto da biblioteca
    .../CastLitePlugin.kt              # integração com Flutter e ActivityAware
    .../CastBrowserActivity.kt         # navegador/transmissão internos
    .../CastingService.kt              # sessão, relay e notificação
  android/src/test/                    # testes Kotlin migrados
cinemax/lib/features/player/services/castlite_bridge_service.dart
cinemax/lib/features/details/presentation/{details_screen.dart,widgets/server_selection_sheet.dart}
cinemax/lib/features/player/presentation/player_screen.dart
cinemax/pubspec.yaml
cinemax/android/{settings.gradle.kts,app/src/main/AndroidManifest.xml}
```

Contrato inicial: versão, identificador da solicitação, conteúdo/episódio, lista de fontes, servidor selecionado, URL, tipo embed/direto, MIME quando conhecido, headers, título, pôster, posição em milissegundos e preferência de áudio. A preferência não garante troca de faixa: verificar suporte da fonte e do receptor. Cookies ficam no contexto da WebView; não presumir que headers reconstruam a sessão. URLs assinadas e cookies não entram nos logs.

Usar Intent explícito para abrir a Activity interna, com `exported=false`, tema AppCompat próprio e recursos prefixados. Manter somente o launcher Flutter. Revisar a fusão do manifesto, `OptionsProvider`, permissões de rede/foreground service/notificações e IDs de notificações. Iniciar descoberta somente ao usar a função; o serviço assume os recursos da transmissão ativa. Falta de Google Play Services desativa apenas as capacidades dependentes dele. Preservar a autenticação na entrada e retornar indisponibilidade controlada em plataformas sem implementação.

## Tarefas e dependências

Responsável recomendado para implementação: `mobile-developer`; skills: `clean-code`, `mobile-design` e `testing-patterns`, conforme cada tarefa. Os nomes indicam especialidade, sem exigir execução por agentes paralelos.

| ID | Prioridade / dependência | Entrada → saída → verificação |
| --- | --- | --- |
| T1 | P0 / nenhuma | Diff local, testes e dependências → baseline e compatibilidade de SDKs registrados → separar falhas anteriores das introduzidas; conferir APIs abaixo do Android 26. |
| T2 | P0 / T1 | `StreamSource` e contexto do episódio → contrato Dart/Kotlin validado → testar headers, URLs assinadas, embed sem extensão, posição, faixa de áudio e rejeição de dados inválidos. |
| T3 | P1 / T1 | Código, assets, recursos e testes CastLite → plugin Android Library → compilar biblioteca e executar testes HLS/detector/catálogo/targets; eliminar conflitos de namespace e recursos. |
| T4 | P1 / T2, T3 | Contrato e plugin → Activity interna e canais de comando/estado → abrir e voltar no mesmo app, tratar cancelamento/erro e recuperar sessão sem conexão duplicada. |
| T5 | P1 / T4 | Chamadas externas existentes → integração interna nos três pontos do CiNey → testar filme, episódio selecionado, servidor, posição e remoção da exigência de instalar CastLite. |
| T6 | P1 / T4 | Activity, serviço, relay e observador → propriedade e liberação de recursos definidas → testar saída da tela, reconexão, troca de título, parada e controles da notificação. |
| T7 | P2 / T5, T6 | App integrado → revisão de interface, dependências e documentação → sem segundo launcher, sem ponte externa ativa, sem duplicação permanente do motor; regressão do host TV verificada. |
| TX | P0 / T7 | Integração revisada → evidência automatizada e física → cumprir a lista final abaixo antes de declarar o app unificado funcional. |

Dependências: `T1 → {T2,T3} → T4 → {T5,T6} → T7 → TX`. Especialidade e skills acima aplicam-se a todas as tarefas; TX prioriza `testing-patterns`.

## Critérios de sucesso e fase X: verificação

- [ ] CiNey inicia e transmite sem CastLite instalado; mantém identidade, autenticação e navegação existentes.
- [x] 24 testes Flutter selecionados passaram: contrato, abertura interna, episódio correto, erros/plataforma indisponível, detalhes/seletor em tela de 360 pixels, histórico e fluxo TV. Também passaram 9 testes JavaScript do observador de mídia.
- [x] Análise Flutter: CiNey sem novos problemas, com dois informes preexistentes de estilo (`--no-fatal-infos`); TV sem problemas. 63 testes JVM passaram; lint Android sem erros (31 avisos); APK compilado e manifesto/assinatura v2 verificados.
- [ ] No celular e TV reais, identificar o protocolo e comprovar imagem, som, áudio selecionado quando disponível, play/pause, seek e posição. Registrar Google Cast, DLNA e Roku separadamente como aprovado, falhou ou não testado.
- [ ] Verificar HLS com variantes, modo econômico, cookies/headers, tela apagada, saída das telas, remoção dos recentes, notificação, interrupção breve de Wi-Fi, troca de filme e encerramento do serviço. Conexão ou aceite de carga não equivalem a reprodução confirmada.
- [x] APK de teste gerado somente localmente: `outputs/CiNey-CastLite-debug-local.apk`. Nenhuma instalação, tag, release ou publicação realizada. Android 8+ confirmado pelo usuário.

Recuperação: mudanças pequenas diretamente em `main`, preservando o diff anterior; se uma etapa falhar, reverter somente sua alteração e manter o player local utilizável. Não remover o projeto de referência antes de verificar paridade. Reescrita integral da interface em Flutter fica para uma etapa posterior à primeira integração funcional.

## Separação dos hosts — 15/10/2026

O núcleo comum passou para `packages/ciney_core`. `cinemax` é o host mobile e
mantém adaptadores CastLite, scanner por câmera, observador de frames e avisos
Android. `cinemax_tv` depende diretamente do núcleo, preservando catálogo,
conta, player e receptor de comandos, sem carregar esses quatro plugins.
Os exports em `cinemax/lib` mantêm compatibilidade dos imports antigos.

Foram removidas as ações de envio na TV e simplificados carrosséis, cartões,
placeholders e splash. Passaram 171 testes Flutter e 40 testes JavaScript,
incluindo a correção do botão central do controle nos diálogos da TV.
Consulte os [resultados e APKs locais](docs/separacao-mobile-tv.md).

### Fechamento da implementação local — 15/10/2026

- [x] Núcleo compartilhado extraído e dependências mobile separadas do host TV.
- [x] Builds mobile e TV concluídos; hashes, assinatura v2, Android mínimo e
  arquiteturas conferidos. APKs TV entre 20,15 e 23,63 MiB por arquitetura.
- [x] Pacotes privados instalados no BlueStacks; ambos iniciaram. Na TV,
  direcional mudou o foco e o botão central abriu o formulário de acesso manual.
- [x] Documentação final atualizada; nenhuma publicação, tag ou release.
- [ ] Validação em TV física: catálogo após login, reprodução, áudio, legendas,
  consumo de recursos e navegação com o controle do aparelho.

A implementação e a entrega local estão concluídas. A instalação mencionada
nesta seção é posterior ao registro da fase X acima e usa somente pacotes de
teste. Os critérios físicos de CastLite continuam pendentes; não representam
uma aprovação automática de transmissão, estabilidade ou faixa de áudio.

## Referências técnicas

[Canais Flutter/Kotlin](https://docs.flutter.dev/platform-integration/platform-channels), [plugins Flutter](https://docs.flutter.dev/packages-and-plugins/developing-packages), [bibliotecas Android](https://developer.android.com/studio/projects/android-library) e [integração Google Cast](https://developers.google.com/cast/docs/android_sender/integrate), consultados em 14/10/2026.
