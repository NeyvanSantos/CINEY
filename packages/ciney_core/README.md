# Núcleo compartilhado do CiNey

Este pacote contém a implementação comum de catálogo, filmes, séries, doramas,
animes, conta, favoritos, histórico, fontes e reprodução. Os hosts são
`../../cinemax` (mobile) e `../../cinemax_tv` (TV).

O núcleo não depende de `castlite_engine`, `mobile_scanner`,
`embed_media_observer` nem `flutter_local_notifications`.
`AppPlatformServices` define os contratos fornecidos pelo host mobile.
O host TV não configura essas capacidades; seus avisos são apresentados no app.

Os arquivos em `cinemax/lib/core`, `features` e `plugin_engine` que apenas
exportam classes mantêm compatibilidade com imports e testes antigos. As
alterações de implementação compartilhada devem ser feitas aqui em `lib/`.
O scanner e os adaptadores nativos ficam no host mobile.

Os recursos são acessados por `AppEnvironment.assetPath`, que resolve o prefixo
`packages/ciney_core/` nos dois hosts.

Os testes de integração compartilhados permanecem em `../../cinemax/test`:

```powershell
cd ../../cinemax
flutter test --no-pub --concurrency=2
node --test test/embed_bridge_test.cjs test/embed_media_observer_test.cjs test/embed_startup_test.cjs
```

Analisar este pacote e ambos os hosts separadamente. O script
`../../scripts/build-local-mobile-tv.ps1` gera somente variantes privadas de
teste, com assinatura de depuração. Os APKs TV são separados por arquitetura;
o script não altera tags, releases ou canais de atualização.
