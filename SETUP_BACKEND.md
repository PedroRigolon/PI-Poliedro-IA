# 🚀 Guia de Configuração do Backend - Poliedro IA

## 📋 Pré-requisitos

1. **MongoDB Atlas Account**
   - Crie uma conta gratuita em: https://www.mongodb.com/cloud/atlas
   - Crie um cluster (tier gratuito M0 é suficiente)
   - Configure um usuário do banco de dados
   - Adicione seu IP à whitelist (ou use 0.0.0.0/0 para desenvolvimento)

2. **Dart SDK** 
   - Já instalado (versão 3.9.2+)

## ⚙️ Configuração Passo a Passo

### 1. Obter Connection String do MongoDB Atlas

1. Acesse [MongoDB Atlas](https://cloud.mongodb.com/)
2. Clique em **"Connect"** no seu cluster
3. Escolha **"Drivers"**
4. Copie a connection string (algo como):
   ```
   mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```
5. Substitua `<username>` e `<password>` pelas suas credenciais

### 2. Criar arquivo .env

Na raiz do projeto (`PI-Poliedro-IA/`), crie um arquivo chamado `.env`:

```env
# MongoDB Atlas
MONGODB_URI=mongodb+srv://seu-usuario:sua-senha@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
DB_NAME=poliedro_ia
USERS_COLLECTION=users

# Server
SERVER_PORT=8080

# JWT Secret (gere uma string aleatória segura)
JWT_SECRET=sua-chave-secreta-super-segura-aqui

# CORS
ALLOWED_ORIGINS=http://localhost:*
```

### 3. Instalar dependências do servidor

```powershell
cd server
dart pub get
cd ..
```

### 4. Iniciar o servidor

```powershell
cd server
dart run bin/server.dart
```

Você deverá ver:
```
✅ Conectado ao MongoDB Atlas
🚀 Servidor rodando em http://localhost:8080
📝 Endpoints disponíveis:
   POST /api/auth/register
   POST /api/auth/login
   POST /api/auth/logout
   GET  /health
```

### 5. Testar o servidor

Abra outro terminal e teste:

```powershell
# Health check
curl http://localhost:8080/health

# Ou use Postman/Insomnia para testar os endpoints de auth
```

## 🔐 Estrutura do Backend

```
server/
├── bin/
│   └── server.dart           # Entry point do servidor
├── lib/
│   ├── routes/
│   │   └── auth_routes.dart  # Rotas de autenticação
│   └── services/
│       ├── auth_service.dart # Lógica de autenticação (JWT, bcrypt)
│       └── database_service.dart # Conexão com MongoDB
└── pubspec.yaml              # Dependências
```

## 📡 Endpoints da API

### POST /api/auth/register
Cadastra novo usuário

**Body:**
```json
{
  "email": "professor@sistemapoliedro.com.br",
  "password": "senha123"
}
```

**Response:**
```json
{
  "message": "Usuário cadastrado com sucesso",
  "user": {
    "email": "professor@sistemapoliedro.com.br",
    "type": "professor"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### POST /api/auth/login
Faz login

**Body:**
```json
{
  "email": "professor@sistemapoliedro.com.br",
  "password": "senha123"
}
```

**Response:**
```json
{
  "message": "Login realizado com sucesso",
  "user": {
    "email": "professor@sistemapoliedro.com.br",
    "type": "professor"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### POST /api/auth/logout
Faz logout

**Headers:**
```
Authorization: Bearer <token>
```

## ✅ Checklist

- [ ] MongoDB Atlas cluster criado
- [ ] Usuário do banco de dados configurado
- [ ] IP adicionado à whitelist
- [ ] Arquivo `.env` criado com suas credenciais
- [ ] Dependências instaladas (`dart pub get`)
- [ ] Servidor iniciado (`dart run bin/server.dart`)
- [ ] Flutter app rodando e conectando ao servidor

## 🐛 Troubleshooting

### Erro: "Connection refused"
- Verifique se o servidor está rodando
- Confirme que a porta 8080 está livre

### Erro: "MongoError: Authentication failed"
- Verifique usuário e senha no `.env`
- Confirme que o usuário foi criado no MongoDB Atlas

### Erro: "IP not whitelisted"
- Adicione seu IP na whitelist do MongoDB Atlas
- Ou adicione 0.0.0.0/0 (apenas para desenvolvimento)

## 📱 Usando no Flutter

O app Flutter já está configurado para se conectar ao servidor em `http://localhost:8080`.

Quando fizer login/registro, o token JWT será salvo automaticamente usando `shared_preferences`.

## 🔒 Segurança

⚠️ **IMPORTANTE:**
- Nunca commite o arquivo `.env` (já está no `.gitignore`)
- Use senhas fortes para MongoDB
- Em produção, use variáveis de ambiente do servidor
- Configure CORS adequadamente para produção
