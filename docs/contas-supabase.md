# Contas e favoritos do CiNey

A autenticação inclui cadastro com e-mail e senha, confirmação por código,
recuperação de senha, perfil editável, saída, exclusão de conta, favoritos
compartilhados e pareamento de Android TV por QR. O catálogo continua acessível
como visitante. Histórico de reprodução, login social e planos pagos ficam para
etapas posteriores.

## Ativar no Supabase

A URL do projeto `fekultszwaxbzejdfluq` e sua chave **publicável** já estão em
[`account_config.dart`](../cinemax/lib/core/config/account_config.dart), com suporte
a substituição por `--dart-define`. A chave publicável é própria para distribuição
no aplicativo; a proteção dos dados é feita pelas políticas do banco. O token
`anon` legado não foi incluído no código. Nunca configure uma chave `service_role`
ou `sb_secret_` no app.

### 1. Criar tabelas e políticas

Abra o [SQL Editor do projeto](https://supabase.com/dashboard/project/fekultszwaxbzejdfluq/sql/new).
Cole o conteúdo completo de
[`202610070001_accounts_and_favorites.sql`](../supabase/migrations/202610070001_accounts_and_favorites.sql)
e execute uma vez. O arquivo usa uma transação e cria:

- `profiles`: nome de exibição, com perfil criado automaticamente no cadastro;
- `favorites`: títulos identificados por usuário, fonte, ID e tipo de conteúdo;
- políticas RLS e permissões para cada usuário acessar somente seus próprios dados;
- `delete_own_account()`: exclusão do usuário autenticado e de seus dados em cascata;
- publicação Realtime para acompanhar mudanças de favoritos em outros aparelhos.

Contas criadas antes da migração também recebem um perfil. A função de exclusão
obtém a identidade da sessão; ela não aceita um ID escolhido pelo aplicativo.
A migração não cria nem altera planos, cobranças ou permissões VIP.

### 2. Ativar o pareamento por QR

Depois de aplicar a migração inicial, execute também
[`202610070002_tv_qr_pairing.sql`](../supabase/migrations/202610070002_tv_qr_pairing.sql).
Ela cria pedidos de pareamento temporários; RLS e privilégios impedem que os
clientes leiam esses pedidos diretamente. Somente a Edge Function usa a chave
de serviço, que nunca deve ser colocada no app.

Instale a [Supabase CLI](https://supabase.com/docs/guides/cli), entre na conta e
vincule o projeto. A partir da raiz do repositório:

```powershell
supabase login
supabase link --project-ref fekultszwaxbzejdfluq
supabase functions deploy tv-pairing --no-verify-jwt
```

A opção `--no-verify-jwt` permite criar e consultar desafios sem login; as ações
que aprovam a conta validam o JWT do Android dentro da função. O segredo de
pareamento é aleatório e válido por cinco minutos; o acesso da TV é um magic
link de uso único.

Na TV, abra **Perfil → Conectar com Android**. No Android já autenticado, abra
**Perfil → Conectar TV** e escaneie o QR mostrado na televisão. Cada aparelho
mantém sua própria sessão; a TV passa a usar a conta aprovada e sincroniza os
favoritos pelo mesmo perfil Supabase.

Favoritos têm uma chave primária UUID opaca e uma restrição única para
usuário/fonte/conteúdo/tipo. A identidade de replicação permanece `default`:
eventos de exclusão levam somente o UUID, pois o Realtime tem limitações na
aplicação de RLS a registros excluídos. Não altere para uma chave primária com
metadados pessoais. [Referência do Realtime](https://supabase.com/docs/guides/realtime/postgres-changes#receiving-old-records).

### 3. Configurar confirmação e recuperação por código

Em **Authentication**, mantenha o provedor de e-mail habilitado e a confirmação
de e-mail obrigatória. Use senha mínima de 8 caracteres no servidor para alinhar
a configuração à validação do app.

Em **Email Templates**, substitua o corpo dos seguintes modelos:

| Modelo | Corpo | Assunto sugerido |
| --- | --- | --- |
| Confirm sign up | [`confirmation.html`](../supabase/templates/confirmation.html) | Confirme sua conta no CiNey |
| Reset password | [`recovery.html`](../supabase/templates/recovery.html) | Recupere sua senha no CiNey |

Os modelos usam `{{ .Token }}`. O usuário digita o código no aparelho em que
iniciou a operação. O app aceita códigos numéricos de 6 a 10 dígitos; configure
um prazo curto de validade, por exemplo 10 minutos. Não são necessários links
profundos, navegador na TV ou configuração de retorno por URL neste fluxo.
O modelo padrão com apenas um link não atende às telas de código do CiNey.
[Referência de modelos de e-mail](https://supabase.com/docs/guides/auth/auth-email-templates).

### 4. Configurar envio de e-mails

Para cadastrar pessoas fora da equipe do projeto, configure **Custom SMTP** com
seu provedor de e-mail e remetente verificado. O serviço padrão do Supabase tem
restrições de destinatários e limites de envio; confira as configurações antes
de distribuir o aplicativo. Credenciais SMTP ficam somente no painel.
[Documentação do SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## Executar e verificar

Depois da configuração do servidor, os comandos normais continuam funcionando:

```powershell
cd cinemax
flutter pub get
flutter run
```

Na TV, execute a partir de `cinemax_tv/`; ambos usam o mesmo projeto Supabase.
Para apontar para um projeto de desenvolvimento:

```powershell
flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA-CHAVE-PUBLICAVEL
```

Verificação manual após ativar:

1. Em **Perfil**, crie uma conta e confirme o código recebido por e-mail.
2. Favorite um título, abra **Perfil → Meus favoritos** e confira sua presença.
3. Entre com a mesma conta no outro aparelho; confira inclusão e remoção.
4. Feche e reabra o app para verificar a restauração da sessão.
5. Edite seu nome e confira o perfil; saia e entre com outra conta para verificar o isolamento.
6. Use **Esqueci minha senha**, confirme o código e defina a nova senha.
7. Em uma conta de teste, use **Gerenciar conta → Excluir conta** e confirme com a senha.
8. Na TV, gere o QR e autorize pelo Android; confira se o perfil e os favoritos
	aparecem na televisão.

Os favoritos são salvos no servidor e precisam de conexão. O app mostra falhas
de gravação e permite recarregar a lista; não há fila de alterações offline nesta
etapa. A tela de favoritos também atualiza ao voltar para o app. Senhas nunca são
armazenadas. A sessão usa o armazenamento seguro da plataforma; os arquivos de
sessão são excluídos do backup Android e do transporte entre dispositivos.

## Organização e testes

- `cinemax/lib/features/auth/`: modelos, acesso ao Supabase, armazenamento seguro e telas;
- `cinemax/lib/features/favorites/`: persistência, lista e botão de favoritos;
- `supabase/migrations/`: alterações versionadas do banco;
- `supabase/functions/tv-pairing/`: emissão e validação do pareamento de TV;
- `supabase/templates/`: corpos dos e-mails;
- `supabase/tests/`: testes de acesso com dois usuários e visitante.

Testes Flutter (sem criar contas nem enviar e-mails reais):

```powershell
cd cinemax
flutter test --no-pub test/accounts_test.dart test/accounts_repository_test.dart
```

Testes do banco, a partir da raiz, com Docker em execução:

```powershell
.\scripts\test_accounts_database.ps1
```

O script cria um PostgreSQL descartável, aplica a migração, verifica isolamento,
cadastro, edição, favoritos e exclusão em cascata e remove o contêiner. Não expõe
portas nem acessa o projeto Supabase remoto. O bootstrap simula a tabela de
usuários e a leitura da identidade do JWT; envio de e-mail, renovação real de
sessão, Realtime e armazenamento nativo exigem a verificação nos aparelhos.
