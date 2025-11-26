# Frontend CRUD Utilisateurs

Petite application frontend statique pour gérer des utilisateurs (CRUD). Elle se connecte aux endpoints exposés par le backend présent dans `crud_app/backend`.

# Frontend CRUD Utilisateurs

Petite application frontend statique pour gérer des utilisateurs (CRUD). Elle se connecte aux endpoints exposés par le backend présent dans `crud_app/backend`.

Pré-requis
- Node.js pour exécuter le backend (si vous utilisez le backend localement)

Endpoints utilisés
- `GET /info` - informations du serveur
- `GET /db/users` - lister
- `GET /db/users/search/:term` - rechercher
- `POST /db/users` - créer
- `PUT /db/users/:id` - mettre à jour
- `DELETE /db/users/:id` - supprimer

Comment lancer
1. Démarrer le backend (depuis `crud_app/backend`):

```bash
npm install
PORT=3000 node index.js
```

2. Servir le dossier `crud_app/frontend` (par exemple):

```bash
# avec Python 3
cd crud_app/frontend
python3 -m http.server 8080
```

Ouvrir ensuite `http://localhost:8080` dans votre navigateur. Si vous servez le frontend sur un autre port/hôte, définissez la variable `window.__API_BASE__` dans la console du navigateur pour pointer vers le backend (ex: `window.__API_BASE__ = 'http://localhost:3000'`).

Docker (build & run)

Le conteneur génère un petit fichier `env.js` au démarrage à partir d'un template (`env.template.js`) pour injecter des variables d'environnement dans la page.

Build image:

```bash
cd crud_app/frontend
docker build -t crud-frontend:latest .
```

Run (exemples):

```bash
# Exposer le frontend sur le port 8080
docker run -p 8080:80 \
	-e API_BASE="http://backend:3000" \
	-e INVENTORY_HOSTNAME="frontend-01" \
	-e ANSIBLE_HOST="203.0.113.12" \
	-e PRIVATE_IP="10.0.1.45" \
	-e REGION="eu-west-1" \
	-e DEPLOYMENT_VERSION="v1.0.0" \
	crud-frontend:latest
```

Notes
- Le conteneur utilise `envsubst` pour substituer les variables définies au runtime dans `env.template.js`. Le script d'entrée `docker-entrypoint.sh` génère `env.js` puis démarre nginx.
- L'application lit `window.__API_BASE__` et `window.__SERVER_INFO__` (injectés via `env.js`) — cela permet de configurer l'URL du backend et d'afficher des informations serveur sans modifier les fichiers statiques.
