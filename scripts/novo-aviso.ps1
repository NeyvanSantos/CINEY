<#
.SYNOPSIS
  Publica um aviso do CiNey para todos os clientes, sem abrir o Supabase Dashboard.

.DESCRIPTION
  Uso interativo:
      .\scripts\novo-aviso.ps1

  Ou direto:
      .\scripts\novo-aviso.ps1 -Titulo "Manutenção" -Mensagem "Servidores em manutenção até 18h."

  O script entra com a sua conta de administrador, desativa os avisos antigos
  e publica o novo. A senha nunca é salva — é pedida a cada execução.
#>
param(
  [string]$Titulo,
  [string]$Mensagem
)

$ErrorActionPreference = 'Stop'

$SupabaseUrl = 'https://fekultszwaxbzejdfluq.supabase.co'
$PublishableKey = 'sb_publishable_Nykhdh_Og6lY_6aPe10r0w_pcuCrNWU'
$AdminEmail = 'neyvanivan@gmail.com'

Write-Host '==================================================='
Write-Host '  CiNey - Publicar aviso para os clientes'
Write-Host '==================================================='

if (-not $Titulo)   { $Titulo   = Read-Host 'Título do aviso' }
if (-not $Mensagem) { $Mensagem = Read-Host 'Texto do aviso' }
if (-not $Titulo.Trim() -or -not $Mensagem.Trim()) {
  throw 'Título e mensagem são obrigatórios.'
}

$password = Read-Host "Senha da conta $AdminEmail" -AsSecureString
$plainPassword = [System.Net.NetworkCredential]::new('', $password).Password

try {
  # Login do administrador (a senha não fica salva em lugar nenhum)
  $login = Invoke-RestMethod -Method Post `
    -Uri "$SupabaseUrl/auth/v1/token?grant_type=password" `
    -Headers @{ apikey = $PublishableKey; 'Content-Type' = 'application/json' } `
    -Body (@{ email = $AdminEmail; password = $plainPassword } | ConvertTo-Json)

  $token = $login.access_token
  $headers = @{
    apikey          = $PublishableKey
    Authorization   = "Bearer $token"
    'Content-Type'  = 'application/json'
    Prefer          = 'return=minimal'
  }

  # Desativa avisos anteriores para o cliente receber só o mais recente
  Invoke-RestMethod -Method Patch `
    -Uri "$SupabaseUrl/rest/v1/app_notifications?is_active=eq.true" `
    -Headers $headers `
    -Body (@{ is_active = $false } | ConvertTo-Json) | Out-Null

  # Publica o novo aviso
  Invoke-RestMethod -Method Post `
    -Uri "$SupabaseUrl/rest/v1/app_notifications" `
    -Headers $headers `
    -Body (@{ title = $Titulo; body = $Mensagem } | ConvertTo-Json) | Out-Null

  Write-Host ''
  Write-Host 'Aviso publicado! Os clientes receberão na próxima abertura do app.'
} catch {
  $detail = $_.ErrorDetails.Message
  if ($detail) { throw "Falha ao publicar o aviso: $detail" }
  throw
} finally {
  $plainPassword = $null
}
