# CiNey

Aplicativo Flutter para descoberta e reprodução de filmes e séries, com catálogo modular por plugins. O código Dart e os assets Flutter são compartilhados entre o app principal e a variante Android TV.

## Projetos

- [`cinemax/`](cinemax/README.md): app principal e fonte única de código Dart, serviços, telas e assets.
- [`cinemax_tv/`](cinemax_tv/README.md): host Android TV com launcher Leanback, banner, manifesto e `applicationId` `com.ciney.tv`. Consome o projeto principal pela dependência local `../cinemax`.
- [`cinemax/regras/`](cinemax/regras/README.md): regras obrigatórias de arquitetura, segurança, builds e releases.

## Requisitos

- Flutter com Dart 3.11.4 ou superior.
- Android SDK e dispositivo ou emulador compatível.
- Para executar a variante TV, use uma Android TV ou um emulador configurado para TV.

## Executar

App principal:

```powershell
cd cinemax
flutter pub get
flutter run
```

Android TV:

```powershell
cd cinemax_tv
flutter pub get
flutter run
```

O modo TV ativa a navegação lateral e o suporte às teclas de mídia do controle no player. As configurações de plataforma, assinatura e banner permanecem em `cinemax_tv/android/`.

## Validar

Execute os testes Dart a partir do projeto principal:

```powershell
cd cinemax
flutter analyze
flutter test --no-pub
node --test test/embed_bridge_test.cjs
```

## Releases

Consulte as [releases do CiNey](https://github.com/NeyvanSantos/CINEY/releases). O app mobile e a Android TV possuem canais de atualização separados; releases TV são identificadas por tags `tv-vX.Y.Z` e publicadas como pré-lançamentos.

