# CastLite integrado

Plugin privado usado pelo CiNey Android. Abre a tela nativa de transmissão no
mesmo pacote, por Intent explícito, e expõe comandos/estados por canais Flutter.
Não exige instalar o aplicativo CastLite.
Requer Android 8 (API 26) ou superior devido ao transporte DLNA/Jetty.

O `android/build.gradle` compila as fontes, recursos, assets e testes existentes
em `CastLite/CastLite/app/src`. Esse diretório é parte necessária do repositório;
não existe uma segunda cópia do motor. O host CastLite independente continua
disponível para comparação e diagnóstico.

O manifesto da biblioteca não exporta telas, não registra deep links e não
adiciona launcher. A descoberta começa ao abrir a tela de transmissão. O envio
fica indisponível no host Android TV e em plataformas sem implementação.

Métodos: `isAvailable`, `open`, `getState`, `showControls`, `play`, `pause`,
`seek` e `stop`. O canal de eventos publica apenas estado e metadados da sessão,
sem URLs, headers ou cookies. Abrir a tela não confirma reprodução na TV.
