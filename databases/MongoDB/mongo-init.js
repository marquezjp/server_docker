// Script de inicialização do MongoDB
// Este script será executado quando o container do MongoDB for criado pela primeira vez

// Conecta ao banco de dados especificado
db = db.getSiblingDB(process.env.MONGO_DATABASE || 'meubancoapp');

// Cria um usuário específico para a aplicação (opcional)
if (process.env.MONGO_APP_USERNAME && process.env.MONGO_APP_PASSWORD) {
  db.createUser({
    user: process.env.MONGO_APP_USERNAME,
    pwd: process.env.MONGO_APP_PASSWORD,
    roles: [
      {
        role: 'readWrite',
        db: process.env.MONGO_DATABASE || 'meubancoapp'
      }
    ]
  });
  
  print('Usuário da aplicação criado com sucesso');
}

// Cria uma coleção de exemplo (opcional)
db.usuarios.insertOne({
  nome: 'Admin',
  email: 'admin@exemplo.com',
  tipo: 'administrador',
  criado_em: new Date()
});

print('Banco de dados inicializado com sucesso');
print('Banco: ' + db.getName());
print('Coleções criadas: ' + db.getCollectionNames());