# Transmissão CastLite dentro do CiNey

O CiNey Android abre o navegador e o controle de transmissão do CastLite dentro
do próprio aplicativo. Os botões ficam nos detalhes do título, em cada episódio,
no seletor de servidores e no player. Não é necessário instalar outro aplicativo.

No navegador integrado, o botão laranja com apenas o ícone de transmissão fica
sempre visível à direita do botão **Ir**, na mesma linha, e abre a seleção de TVs.

## Código e fluxo

- `cinemax/packages/castlite_engine`: API Dart e plugin Android com `ActivityAware`.
- `CastLite/CastLite/app/src`: fonte única do motor nativo, recursos, JavaScript e
  testes. O plugin referencia esses diretórios pelo Gradle; o host independente
  continua disponível para diagnóstico, sem duplicação de código.
- `CastLiteBridgeService`: monta o contrato versionado e aciona o canal interno.
- A implementação comum agora está em `packages/ciney_core`; o host mobile
  fornece o adaptador em `cinemax/lib/mobile/mobile_services.dart`.
- As telas nativas são privadas (`exported=false`) e abertas por Intent explícito.
  O launcher e o pacote do CiNey continuam sendo os do aplicativo principal.
- A lista de servidores, episódio, posição, pôster, headers e preferência de áudio
  acompanham a solicitação. O menu nativo permite trocar de servidor.
- O Google Cast recebe a posição no carregamento da mídia; nos outros protocolos
  o serviço tenta aplicar a posição depois do aceite e do início da reprodução.
- Cookies e cabeçalhos da fonte ficam em memória. Os eventos enviados ao Flutter
  contêm estado, título, servidor, episódio e posição, sem URL ou credenciais.

O serviço mantém o relay e os recursos do navegador durante uma transmissão
ativa. A notificação permite reproduzir, pausar, voltar dez segundos e parar.
Ao encerrar a sessão, os recursos são liberados. Após a morte do processo, uma
fonte temporária precisa ser aberta novamente.

O plugin não inicia descoberta ao abrir o catálogo. A variante Android TV não
depende do CastLite nem de DLNA/Jetty; mantém seu player e receptor de comandos
do celular. O mínimo continua **Android 8 / API 26** por decisão existente. O
motor completo fica no mobile. Consulte a [separação dos hosts](separacao-mobile-tv.md).

## Verificação local

Na pasta `cinemax`:

```powershell
flutter pub get
flutter test --no-pub test/castlite_bridge_test.dart test/castlite_entrypoints_test.dart test/details_auto_play_test.dart test/watch_history_repository_test.dart test/tv_cast_service_test.dart
flutter analyze --no-pub
```

Na pasta `cinemax/android`, com JDK 17:

```powershell
.\gradlew.bat :castlite_engine:testDebugUnitTest :castlite_engine:lintDebug
```

Para a variante TV, executar `flutter pub get` e `flutter analyze --no-pub` em
`cinemax_tv`. O APK local deve ser compilado pelo Flutter, sem acionar os scripts
de publicação ou os workflows de release.

Neste checkout Windows, CMake/JNI exige um caminho sem acentos. A partir da raiz,
usar `powershell -ExecutionPolicy Bypass -File scripts/build-castlite-local.ps1`.
O script cria uma unidade virtual temporária, compila apenas um APK de depuração
e remove o alias ao terminar. Não instala, assina para release ou publica nada.

## Teste necessário em aparelhos

1. Instalar a compilação de teste em um celular e abrir o CiNey sem CastLite instalado.
2. Transmitir um arquivo MP4 público, depois uma fonte HLS, verificando imagem,
   som, posição e controles no receptor. Registrar qual protocolo foi usado.
3. Escolher um episódio diferente do primeiro, trocar de servidor e verificar se
   título e episódio continuam corretos.
4. Verificar áudio dublado quando a fonte oferecer essa faixa. Receber uma
   preferência de idioma não garante que o receptor tenha escolhido a faixa.
5. Apagar a tela, sair das telas do app, testar a notificação e uma interrupção
   breve de Wi-Fi. Conferir parada e liberação do relay.
6. Repetir separadamente para Google Cast, DLNA e Roku disponíveis no ambiente.

Abertura da tela, conexão com o dispositivo e aceite do carregamento são
estados diferentes de reprodução confirmada. Nenhum protocolo deve ser marcado
como aprovado em uma TV com base apenas nos testes automatizados.

Distribuição pública não autorizada nesta integração. Não criar tag, GitHub
Release, enviar atualização aos usuários ou executar scripts de publicação.

## Resultado desta implementação — 14/10/2026

- 24 testes Flutter selecionados passaram, incluindo os novos pontos de entrada
  em viewport de 360 × 800, histórico e fluxo compartilhado da TV.
- 63 testes JVM do motor e 9 testes JavaScript do observador passaram.
- Lint Android do módulo: zero erros e 31 avisos. Análise Flutter do CiNey:
  zero erros/avisos e dois informes de estilo preexistentes em `tv_cast_service.dart`;
  `--no-fatal-infos` conclui com sucesso. Análise da variante TV: nenhum problema.
- APK de depuração compilado e assinatura v2 verificada, com um assinante.
  Pacote `com.ciney.app`, versão `1.0.39+36`, mínimo API 26, ARMv7/ARM64/x86_64.
- Manifesto conferido: somente o launcher CiNey; as duas telas CastLite são
  privadas e não possuem filtros de Intent. DEX do plugin/serviço/navegador e
  asset do observador de frames estão presentes no APK.
- Cópia local: `outputs/CiNey-CastLite-debug-local.apk`, 194.792.109 bytes.
  SHA-256: `8495FB29D7B71A1D750331B5F71468B900DB9DD1709D8E1D6DFBA11525027BC7`.
- Nenhum aparelho estava conectado ao ADB. A instalação e a reprodução física
  desta compilação continuam pendentes, incluindo dublagem e segundo plano.

O APK usa assinatura de depuração; não atualiza uma instalação oficial que
tenha outro certificado. Nenhuma tag, release ou atualização pública foi criada.
