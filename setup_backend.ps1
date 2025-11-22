# Script de setup do backend
Write-Host "🚀 Configurando Backend do Poliedro IA..." -ForegroundColor Cyan
Write-Host ""

# Verifica se o arquivo .env existe
if (!(Test-Path ".env")) {
    Write-Host "⚠️  Arquivo .env não encontrado!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Por favor, crie um arquivo .env na raiz do projeto com o seguinte conteúdo:" -ForegroundColor White
    Write-Host ""
    Write-Host "MONGODB_URI=sua-connection-string-aqui" -ForegroundColor Gray
    Write-Host "DB_NAME=poliedro_ia" -ForegroundColor Gray
    Write-Host "USERS_COLLECTION=users" -ForegroundColor Gray
    Write-Host "SERVER_PORT=8080" -ForegroundColor Gray
    Write-Host "JWT_SECRET=sua-chave-secreta-aqui" -ForegroundColor Gray
    Write-Host "ALLOWED_ORIGINS=http://localhost:*" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📝 Use o arquivo .env.example como referência" -ForegroundColor Cyan
    exit 1
}

Write-Host "✅ Arquivo .env encontrado" -ForegroundColor Green

# Instala dependências do servidor
Write-Host ""
Write-Host "📦 Instalando dependências do servidor..." -ForegroundColor Cyan
Set-Location server
dart pub get

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Dependências instaladas com sucesso!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao instalar dependências" -ForegroundColor Red
    Set-Location ..
    exit 1
}

Set-Location ..

Write-Host ""
Write-Host "🎉 Setup concluído!" -ForegroundColor Green
Write-Host ""
Write-Host "Para iniciar o servidor, execute:" -ForegroundColor White
Write-Host "  cd server" -ForegroundColor Cyan
Write-Host "  dart run bin/server.dart" -ForegroundColor Cyan
Write-Host ""
