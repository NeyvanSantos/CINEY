# Contribuindo

## Executar

```powershell
cd cinemax
flutter pub get
flutter run
```

## Testar

Execute em `cinemax/`:

```powershell
flutter analyze
flutter test --no-pub
node --test test/embed_bridge_test.cjs test/embed_media_observer_test.cjs test/embed_startup_test.cjs
```

## Commits e mudanças protegidas

Use commits no formato `tipo: resumo curto em português`, por exemplo
`docs: atualizar instruções`. Mudanças em `cinemax/regras/` e no player Android
TV exigem discussão prévia antes de serem propostas.

Consulte também o [mapa da estrutura do projeto](docs/estrutura.md).