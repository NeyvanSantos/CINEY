# Notas de continuidade do CiNey

## Recuperacao antes da otimizacao de fluidez - 2026-10-23

Backup: `.work/recovery/20261023-132425`. O manifest.json lista os arquivos copiados.
Estado: main em 8eb02a8, com alteracoes locais anteriores preservadas. TV 192.168.100.130:5555; pacote de teste com.ciney.tv.lite_test, versao 1.0.46-teste-local. Painel removido; Voltar sai, Menu abre servidores. Historico nao bloqueia abertura na TV; scripts carregam em paralelo. SuperFlix reproduziu abertura, mas fluidez nao certificada. Amostra anterior: interface com 6,6% de quadros atrasados; isso nao mede diretamente quadros perdidos do filme.

Se regredir: copiar SOMENTE os arquivos do manifest.json do backup para seus caminhos relativos na raiz, recompilar com `scripts/build-local-mobile-tv.ps1 -Target tv` e instalar outputs/CiNey-TV-Leve-teste-armeabi-v7a.apk com adb install -r no pacote de teste. Nao usar git reset/clean, nao apagar dados da TV e nao publicar. O APK em outputs ainda e a referencia anterior ate o proximo build; validar comportamento fisico apos restaurar.

## Foco e atualizacoes do player
Backup adicional: .work/recovery/tv-focus-performance. Restaurar os dois arquivos pelos caminhos relativos se houver regressao.

## SuperFlix HLS binario
Backup do observador antes deste ajuste: .work/recovery/before-superflix-hls/tv_hls_observer.js. Validacao fisica pendente.

## Limite de imagens TV
Backup: .work/recovery/before-tv-image-memory/manifest.json. Cache TV 32 MiB/120 imagens; entrada do player limpa somente cache reutilizavel; fundo de detalhes decodificado na largura fisica da tela. Nao limpa cookies, dados nem imagens vivas. Ganho fisico pendente de medicao.

## Player dedicado TV
Backup: .work/recovery/before-dedicated-tv/manifest.json. Novos arquivos: NativeTvPlayerActivity.kt. Prototipo Media3/SurfaceView e canal com.ciney/tv_native_player. Validacao pendente; nao publicar antes de reteste fisico.

Player dedicado instalado e exercitado na TV: primeiro quadro, OMX.MS.AVC.Decoder e retorno Menu para selecao de servidores confirmados. 644 quadros renderizados/36 descartados em amostra curta: fluidez ainda nao certificada. Evidencias em docs/plano-player-tv-surfaceview.md.

## SuperFlix: causa confirmada e transporte
Menu delegado exige evento original isTrusted: .click() JS e ignorado. OK passa a solicitar toque Android no centro do item, condicionado a confirmacao recente. Teste ADB de toque abriu player. JW audio Portugues selecionado e legendas Portuguese ativas. HLS master.txt retorna200 via browser/403 direto. Novo transporte autentica requisicoes no frame validado, spool em disco e ACK por bloco; Media3 decodifica, WebView pausa video local. Validacao final pendente. Backup previa validacao: .work/recovery/before-superflix-validation.

### Cursor no seletor SuperFlix (2026-10-23)
Modo de mouse limitado ao menu reconhecido do SuperFlix: setas movem cursor laranja, OK solicita toque Android com confirmação física recente. Oculta cursor ao sair do seletor/iniciar vídeo. Outros provedores preservam navegação por foco. Testes JS: 5 passaram. Validação física pendente após instalar APK.


Validação física do cursor concluída: APK teste instalado com Success; setas moveram cursor; OK abriu iframe do player SuperFlix (toque Android confirmado). Na recompilação final, inspeção da TV mostrou menu=false e cursor=none após OK. Seletor coberto pelo player não intercepta teclas. 6 testes de navegação e 10 de HLS/transporte passaram. Isso não certifica reprodução fluida: houve erro posterior de reprodução no teste anterior.


### Diagnóstico SuperFlix / Shrek 2026-10-23
TV física: WebView PIPELINE_ERROR_DECODE no conteúdo; tentativa nativa transport=browser falhou errorCode=2000 antes de renderizar. Verificação no mesmo frame/sessão: master/variant HTTP200; segmento fetch credentials=include falha TypeError, enquanto same-origin retorna200, 1.367.700 bytes, TS sync 0x47 em 0/188/376. Corrigido transporte para credentials=same-origin (padrão do navegador), preservando cookies da origem e compatibilidade CORS no CDN. Reprodução física após correção ainda pendente.


## Teste Shrek 2 em ambos os servidores — 2026-10-29

TV conectada e autorizada. APK instalado confirmado pelo SHA-256 959875E436C16EF9BBA7180F8ED838B930AA8BFF4CB23B32CCD4693F934BBD70; o build local F3DF8C066C9FCA08B931A3CF0D042F28EED04270AB0B681B05D3DE17BE195BBB (filas assíncronas Media3) ainda NÃO foi instalado/validado. Não confundir código local com APK em execução.

Shrek 2 (2004): EmbedMovies 720p, 3819 renderizados/6 descartados; SuperFlix principal 240p, 4263/15. Pausa/retomada/busca funcionaram, sem erro e sem buffering além de abertura/busca nas amostras. SuperFlix demorou na navegação/validação antes do player; motivo da seleção 240p pendente. Não certificar alta qualidade ou filme inteiro com essa amostra. Relatório: docs/teste-tv-shrek2-2026-10-29.md; evidências: outputs/tv-shrek2-2026-10-29/. Nenhuma alteração de implementação nesta etapa. TV deixada no seletor de servidores.
