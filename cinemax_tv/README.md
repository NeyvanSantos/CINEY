# CiNey TV

Host Android TV do [app compartilhado](../cinemax/README.md), com `applicationId`
`com.ciney.tv`. A entrada em [`lib/main.dart`](lib/main.dart) chama
`runCinemaxApp(isTv: true)`. As telas, serviços, motor de plugins e assets vêm de
`../cinemax`, declarado como dependência local no `pubspec.yaml`.

## Executar na TV

Conecte uma Android TV ou inicie um emulador de TV e execute nesta pasta:

```powershell
flutter pub get
flutter run
```

O launcher registra Leanback e touchscreen opcional. A navegação lateral é
ativada pelo modo TV do app compartilhado, e o player nativo responde às teclas
de mídia. O banner fica em `android/app/src/main/res/drawable/tv_banner.xml`.

## Validar

```powershell
flutter analyze
Push-Location ../cinemax
flutter test --no-pub
node --test test/embed_bridge_test.cjs
Pop-Location
```

Os testes ficam no projeto principal, junto da implementação compartilhada.

## Releases e documentação

A variante TV mantém versão e configurações de assinatura próprias. A
identificação da variante seleciona releases e APKs TV no atualizador
compartilhado. As releases TV usam tags `tv-vX.Y.Z` e são publicadas como
pré-lançamentos no [repositório oficial](https://github.com/NeyvanSantos/CINEY/releases).
O workflow e os scripts de publicação mobile não publicam a variante TV.

O último APK TV publicado fica em `../releases/tv/`, conforme a
[política de armazenamento local](../releases/README.md). Os binários não são
versionados no Git.

- [Recursos, reprodução, transmissão e privacidade](../README.md)
- [Mapa do código-fonte e das pastas](../docs/estrutura.md)
- [Regras compartilhadas de desenvolvimento](../cinemax/regras/README.md)
- [Notas de otimização](../docs/performance-optimization.md)
- [Receptor Google Cast compartilhado](../receiver/README.md)
