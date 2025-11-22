# Script para iniciar o servidor backend
Write-Host "🚀 Iniciando servidor backend..." -ForegroundColor Cyan
Write-Host ""

# Verifica se o arquivo .env existe
if (!(Test-Path "../.env")) {
    Write-Host "❌ Arquivo .env não encontrado na raiz do projeto!" -ForegroundColor Red
    Write-Host "Execute primeiro: .\setup_backend.ps1" -ForegroundColor Yellow
    exit 1
}

# Inicia o servidor
dart run bin/server.dart
