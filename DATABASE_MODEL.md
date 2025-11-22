# Modelagem do Banco de Dados MongoDB - Poliedro IA

## 📊 Estrutura do Banco

### Database: `poliedro_ia`

---

## 📋 Collections

### 1. **users** (Usuários do Sistema)

Armazena informações de autenticação e perfil dos usuários.

#### Schema:
```json
{
  "_id": ObjectId,
  "email": String,           // Email institucional único
  "password": String,        // Hash bcrypt da senha
  "type": String,            // "professor" ou "student"
  "createdAt": ISODate,      // Data de criação da conta
  "updatedAt": ISODate,      // Última atualização do perfil
  "lastLogin": ISODate       // Último acesso (opcional)
}
```

#### Indexes:
- `email`: UNIQUE INDEX (garante emails únicos)
- `type`: INDEX (consultas por tipo de usuário)
- `createdAt`: INDEX (ordenação cronológica)

#### Validações:
- `email`: 
  - Obrigatório
  - Deve terminar com `@sistemapoliedro.com.br` ou `@p4ed.com`
  - Formato de email válido
- `password`: 
  - Obrigatório
  - Hash bcrypt com 10 rounds
  - Mínimo 6 caracteres antes do hash
- `type`:
  - Obrigatório
  - Enum: ["professor", "student"]
  - Determinado automaticamente pelo domínio do email

#### Exemplo de Documento:
```json
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "email": "joao.silva@sistemapoliedro.com.br",
  "password": "$2b$10$X7qZ9R2L.kJ8mN5pQ3tY8e...",
  "type": "professor",
  "createdAt": "2024-11-22T10:30:00.000Z",
  "updatedAt": "2024-11-22T10:30:00.000Z",
  "lastLogin": "2024-11-22T14:45:30.000Z"
}
```

---

### 2. **diagrams** (Diagramas Criados - Futura Implementação)

Armazena os diagramas criados pelos usuários.

#### Schema (Proposto):
```json
{
  "_id": ObjectId,
  "userId": ObjectId,        // Referência ao usuário criador
  "userEmail": String,       // Email do usuário (denormalizado para performance)
  "title": String,           // Título do diagrama
  "description": String,     // Descrição (opcional)
  "category": String,        // "fisica", "quimica", "geral"
  "shapes": Array,           // Array de formas do diagrama
  "imageUrl": String,        // URL da imagem gerada (opcional)
  "isPublic": Boolean,       // Se o diagrama é público
  "createdAt": ISODate,
  "updatedAt": ISODate
}
```

#### Indexes (Propostos):
- `userId`: INDEX
- `userEmail`: INDEX
- `category`: INDEX
- `createdAt`: INDEX (ordenação)
- `isPublic`: INDEX (filtros)

---

### 3. **sessions** (Sessões - Futura Implementação)

Para gerenciar sessões e invalidação de tokens.

#### Schema (Proposto):
```json
{
  "_id": ObjectId,
  "userId": ObjectId,
  "token": String,           // Token JWT
  "refreshToken": String,    // Token de renovação
  "isActive": Boolean,
  "expiresAt": ISODate,
  "createdAt": ISODate,
  "lastActivity": ISODate
}
```

---

## 🔐 Regras de Negócio

### Autenticação:
1. **Registro**:
   - Valida email institucional
   - Hash da senha com bcrypt (10 rounds)
   - Tipo determinado automaticamente:
     - `@sistemapoliedro.com.br` → `professor`
     - `@p4ed.com` → `student`
   - Gera JWT token válido por 7 dias

2. **Login**:
   - Verifica credenciais
   - Atualiza `lastLogin`
   - Retorna token JWT

3. **Logout**:
   - Invalida token (cliente remove do storage)
   - Futuramente: blacklist de tokens

### Segurança:
- Senhas NUNCA são armazenadas em texto plano
- Tokens JWT assinados com chave secreta
- HTTPS obrigatório em produção
- CORS configurado para origens permitidas

---

## 📈 Scripts de Manutenção

### Criar Índices (executar após deploy):
```javascript
// No MongoDB Shell ou Compass
use poliedro_ia;

// Índice único de email
db.users.createIndex({ "email": 1 }, { unique: true });

// Índice de tipo de usuário
db.users.createIndex({ "type": 1 });

// Índice de data de criação
db.users.createIndex({ "createdAt": -1 });
```

### Consultas Úteis:
```javascript
// Total de usuários por tipo
db.users.aggregate([
  { $group: { _id: "$type", count: { $sum: 1 } } }
]);

// Usuários criados nos últimos 7 dias
db.users.find({
  createdAt: {
    $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  }
});

// Últimos logins
db.users.find().sort({ lastLogin: -1 }).limit(10);
```

---

## 🚀 Migração e Versionamento

### Versão 1.0.0 (Atual)
- Collection `users` com autenticação básica
- JWT tokens
- Validação de emails institucionais

### Versão 1.1.0 (Planejada)
- Collection `diagrams` para salvar trabalhos
- Collection `sessions` para gerenciamento de tokens
- Sistema de compartilhamento de diagramas

### Versão 2.0.0 (Futura)
- Analytics de uso
- Templates compartilhados pela comunidade
- Comentários e colaboração em diagramas
