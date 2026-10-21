# Validação local do player TV — 20/10/2026

## Implementação

- O host TV voltou a registrar o plugin de observação de frames e a ponte nativa
  de foco/teclas.
- Playlists HLS observadas no servidor são encaminhadas ao player nativo com
  formato explícito e dados da sessão. A playlist principal mantém as variantes
  de qualidade e as faixas de áudio. Português é preferido quando identificado.
- Dublado, Legendado e servidores recebem foco laranja. As setas movem o foco e
  OK confirma; o cartão inteiro fica destacado. O menu aguarda a escolha.
- O menu de recuperação oferece recarregar, trocar servidor e sair. O botão de
  recarga duplicado ao suspender foi removido.

## Evidência

O AVD `Television_1080p`, serial `emulator-5554`, foi iniciado pelo CLI do
RustDroid na janela existente do projeto, sem abrir outro editor. A janela foi
reconectada após a pausa da sessão.

| Verificação | Resultado |
| --- | --- |
| Suíte Flutter do host mobile/núcleo | 178 testes aprovados. |
| JavaScript: ponte, observação HLS, inicialização e D-pad | 47 testes aprovados. |
| Regressão do menu após remover recarga duplicada | 11 testes aprovados. |
| Regressão do atualizador | 7 testes aprovados. |
| Análise dos arquivos do player alterados | Sem problemas. |
| HLS local no Android real do AVD | Reprodução, pausa, avanço e liberação aprovados. |
| Sessão da fixture HLS AES-128 | 3 playlists, 10 segmentos, 1 chave e nenhuma recusa. |
| EmbedMovies, filme TMDB 157336 | Teste Android aprovado em 57 segundos, incluindo mais 30 segundos de progressão após pausa/avanço. A duração nativa foi validada como superior a duas horas. |
| Foco no menu real do SuperFlix | D-pad nativo moveu o foco de Principal para Alternativo; captura em `outputs/tv-hls-remote-focus.png`. |
| Reprodução pelo SuperFlix | Não aprovada: o código do fornecedor falha em `Object.init` com `TypeError: this[...] is not a function`. O método exato não foi confirmado. O menu aparece, mas a inicialização não chega ao HLS. |

Os testes de reprodução usam o `PlayerScreen`, a WebView e o decoder Android
reais. Somente o catálogo é substituído pelo teste para escolher o endereço sem
depender de login ou navegação no catálogo.

O relógio restaurado no AVD estava em 16/10 e foi corrigido para 20/10. Antes da
correção, a verificação do SuperFlix informava explicitamente hora incorreta.
A navegação reconhece o redirecionamento observado para `superflixapi.fun`.
O diagnóstico foi feito no script real carregado pela WebView. A implementação
não substitui nem desativa verificações do fornecedor. A fonte
EmbedMovies permaneceu funcional no teste de reprodução descrito acima.

Há três avisos informativos preexistentes na análise geral do núcleo, em
`extensions_screen.dart` e `tv_cast_service.dart`; não são erros dos arquivos
alterados. A validação no AVD não confirma reprodução na TV física nem uma
sessão de filme completa.

Comandos e preparação da fixture: [tv-hls-playback.md](tv-hls-playback.md).

## APK local entregue

- Arquivo: `artifacts/tv/CiNey-1.0.44-HLS-local-TV.apk`.
- Pacote `com.ciney.tv.local`, versão `1.0.44-hls-local`, código 46.
- Android mínimo 26; ARMv7, ARM64 e x86_64; assinatura v2 verificada.
- Tamanho: 203.188.540 bytes.
- SHA-256: `5546416e68fecc256bfa666c59f2706823f9b496db88bd36ec723c28d8b18fbb`.
- Instalado no AVD do RustDroid; a versão publicada permanece em outro pacote.
- O pacote local usa instalação manual e não oferece a atualização pública.
- A abertura normal chegou à tela de entrada da TV com foco visível, sem o
  aviso de atualização pública. Captura: `outputs/tv-hls-local-app.png`.

A exclusão das pastas de mídia sintética foi recusada pela revisão automática
com o motivo `blocked by policy`. As pastas permanecem em `.work`, ignoradas no
Git. São arquivos gerados localmente e podem ser recriados pelo script da fixture.
