# Publicação mobile e TV 1.0.45 — 20/10/2026

Publicação dos dois aplicativos autorizada pelo usuário. Mobile `com.ciney.app`,
versão 1.0.45+42; TV `com.ciney.tv`, versão 1.0.45+47.

## Alterações

- Mobile: Voltar e Trocar servidor ocultos no início dos embeds; um toque
  revela os botões por quatro segundos sem impedir a interação com o fornecedor.
- TV: observação HLS nos frames, preparação nativa com sessão preservada,
  foco laranja e navegação por D-pad nas opções de áudio e servidores.
- TV: entrega do foco ao fornecedor e recuperação por recarga/troca de fonte.
- O pacote debug de testes `com.ciney.tv.local` não modifica a identidade ou o
  canal de atualização da versão pública.

## Validação de reprodução anterior à publicação

[Relatório local](../tv-hls-validation-2026-10-20.md): HLS local AES-128 e
EmbedMovies reproduziram no AVD Android TV do RustDroid, com pausa, avanço e
retomada. O SuperFlix apresentou erro em `Object.init` no código do fornecedor;
sua reprodução não foi aprovada. Não houve teste em TV física.

## Publicação

Os resultados finais de CI, downloads, assinatura e abertura dos APKs públicos
serão registrados após a conclusão dos workflows.
