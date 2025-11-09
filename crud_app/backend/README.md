# Backend API avec PostgreSQL - Tests de Base de Données

Ce backend permet de tester les opérations de lecture et d'écriture avec PostgreSQL géré par Patroni.

## Configuration

1. Copiez `.env.example` vers `.env` et configurez vos variables :
```bash
cp .env.example .env
```

2. Mettez à jour `DATABASE_URL` avec l'endpoint de votre Network Load Balancer PostgreSQL :
```
DATABASE_URL=postgresql://admin:admin123@your-postgresql-nlb.elb.region.amazonaws.com:5432/postgres
```

3. Installez les dépendances :
```bash
npm install
```

## Endpoints Disponibles

### ⚡ Health Checks
- `GET /health` - Santé générale de l'application
- `GET /health/database` - Santé de la base de données et pool de connexions
- `GET /db/test` - Test de connexion PostgreSQL

### 🔧 Initialisation
- `POST /db/init` - Initialiser les tables de test

### ✍️ Opérations d'Écriture (INSERT/UPDATE)
- `POST /db/users` - Créer un utilisateur
  ```json
  {
    "name": "Jean Dupont",
    "email": "jean@example.com"
  }
  ```
- `PUT /db/users/:id` - Mettre à jour un utilisateur
- `POST /db/users/bulk` - Insertion en lot d'utilisateurs
  ```json
  {
    "users": [
      {"name": "User1", "email": "user1@test.com"},
      {"name": "User2", "email": "user2@test.com"}
    ]
  }
  ```
- `POST /db/logs` - Ajouter une entrée de log
  ```json
  {
    "message": "Test log message",
    "level": "INFO"
  }
  ```

### 📖 Opérations de Lecture (SELECT)
- `GET /db/users` - Lister tous les utilisateurs (avec pagination)
  - Query params : `limit`, `offset`
- `GET /db/users/:id` - Obtenir un utilisateur par ID
- `GET /db/users/search/:term` - Rechercher des utilisateurs
- `GET /db/logs` - Lister les logs
  - Query params : `limit`, `level`
- `GET /db/stats` - Statistiques de la base de données

### 🗑️ Opérations de Suppression
- `DELETE /db/users/:id` - Supprimer un utilisateur
- `DELETE /db/clear` - Vider toutes les données de test

## Exemples de Tests

### Test Complet de Lecture/Écriture

1. **Initialiser la base** :
```bash
curl -X POST http://localhost:3001/db/init
```

2. **Créer des utilisateurs** :
```bash
curl -X POST http://localhost:3001/db/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Martin", "email": "alice@test.com"}'

curl -X POST http://localhost:3001/db/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Bob Durand", "email": "bob@test.com"}'
```

3. **Lire les utilisateurs** :
```bash
curl http://localhost:3001/db/users
```

4. **Rechercher** :
```bash
curl http://localhost:3001/db/users/search/Alice
```

5. **Ajouter des logs** :
```bash
curl -X POST http://localhost:3001/db/logs \
  -H "Content-Type: application/json" \
  -d '{"message": "Test de connexion PostgreSQL", "level": "INFO"}'
```

6. **Voir les statistiques** :
```bash
curl http://localhost:3001/db/stats
```

## Monitoring

- Le pool de connexions PostgreSQL est surveillé
- Chaque requête est loggée avec sa durée d'exécution
- Les erreurs sont capturées et retournées proprement

## Structure des Tables de Test

### `test_users`
- `id` (SERIAL PRIMARY KEY)
- `name` (VARCHAR(100))
- `email` (VARCHAR(100) UNIQUE)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### `test_logs`
- `id` (SERIAL PRIMARY KEY)
- `message` (TEXT)
- `level` (VARCHAR(20))
- `created_at` (TIMESTAMP)

## Démarrage

```bash
npm start
```

L'API sera disponible sur `http://localhost:3001`