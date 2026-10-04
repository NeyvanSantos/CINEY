# CineMax Custom Receiver

Este receiver precisa ser hospedado em uma URL HTTPS publica e cadastrado no Google Cast Developer Console.

## Registro

1. Acesse o Google Cast Developer Console.
2. Crie um aplicativo do tipo Custom Receiver.
3. Informe a URL HTTPS onde `receiver.html` sera hospedado.
4. Copie o Application ID gerado.

## Build do app

Passe o ID ao Gradle ao gerar a APK:

```powershell
Push-Location android
.\gradlew.bat assembleDebug -PcinemaxCastReceiverAppId=SEU_APP_ID
Pop-Location
```

O namespace usado pelo app e pelo receiver e:

```text
urn:x-cast:com.cinemax.receiver
```

O receiver reproduz fontes diretas em um elemento `video` e paginas EmbedMovies em um `iframe`. O provedor ainda pode bloquear iframe, cookies, DRM ou carregamento externo.
