const { Pool } = require('pg');
const { config } = require('./config');
const { PostgreSQLClusterManager } = require('./database-cluster');

// Determine if we're using cluster mode or direct connection
const USE_CLUSTER_MODE = config.database.useCluster !== false ; // Default to false

let dbManager = null;
let pool = null;

// Initialize database connection
const initializeConnection = async () => {
    if (USE_CLUSTER_MODE) {
        console.log('[Database] Initializing cluster connection mode...');

        // Parse database configuration
        const dbConfig = parseConnectionConfig(config.database.url);

        dbManager = new PostgreSQLClusterManager({
            region: config.database.region,
            database: dbConfig.database,
            user: dbConfig.user,
            password: dbConfig.password,
            port: dbConfig.port,
            max: config.database.poolConfig.max,
            idleTimeoutMillis: config.database.poolConfig.idleTimeoutMillis,
            connectionTimeoutMillis: config.database.poolConfig.connectionTimeoutMillis,
            maxUses: config.database.poolConfig.maxUses
        });

        await dbManager.initialize();
    } else {
        console.log('[Database] Initializing direct connection mode...');

        // Configuration de la base de données avec chaîne de connexion
        const dbConfig = {
            connectionString: config.database.url,
            max: config.database.poolConfig.max,
            idleTimeoutMillis: config.database.poolConfig.idleTimeoutMillis,
            connectionTimeoutMillis: config.database.poolConfig.connectionTimeoutMillis,
            maxUses: config.database.poolConfig.maxUses,
            ssl: false // Désactivé pour l'environment interne
        };

        // Création du pool de connexions
        pool = new Pool(dbConfig);

        // Gestion des erreurs du pool
        pool.on('error', (err, client) => {
            console.error('Erreur inattendue sur un client inactif', err);
            process.exit(-1);
        });
    }
};

// Parse database connection string or config
function parseConnectionConfig(urlOrConfig) {
    if (typeof urlOrConfig === 'string') {
        // Parse connection string: postgresql://user:pass@host:port/database
        const match = urlOrConfig.match(/postgresql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)/);
        if (match) {
            return {
                user: match[1],
                password: match[2],
                host: match[3],
                port: parseInt(match[4]),
                database: match[5]
            };
        }
    }
    return urlOrConfig;
}

// Fonction pour exécuter une requête
const query = async (text, params) => {
    const start = Date.now();
    try {
        const res = USE_CLUSTER_MODE
            ? await dbManager.query(text, params)
            : await pool.query(text, params);
        const duration = Date.now() - start;
        console.log(`Requête exécutée: ${text.substring(0, 50)}... (${duration}ms)`);
        return res;
    } catch (error) {
        console.error('Erreur lors de l\'exécution de la requête:', error);
        throw error;
    }
};

// Fonction pour obtenir un client du pool
const getClient = async () => {
    return USE_CLUSTER_MODE
        ? await dbManager.getClient()
        : await pool.connect();
};

// Fonction pour initialiser la base de données avec des tables de test
const initDatabase = async () => {
    try {
        // Créer une table de test si elle n'existe pas
        await query(`
            CREATE TABLE IF NOT EXISTS test_users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Créer une table de logs pour les tests
        await query(`
            CREATE TABLE IF NOT EXISTS test_logs (
                id SERIAL PRIMARY KEY,
                message TEXT NOT NULL,
                level VARCHAR(20) DEFAULT 'INFO',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        // Créer un index sur email pour optimiser les recherches
        await query(`
            CREATE INDEX IF NOT EXISTS idx_test_users_email 
            ON test_users(email)
        `);

        console.log('Base de données initialisée avec succès');
        return true;
    } catch (error) {
        console.error('Erreur lors de l\'initialisation de la base de données:', error);
        throw error;
    }
};

// Fonction pour tester la connexion
const testConnection = async () => {
    try {
        if (USE_CLUSTER_MODE) {
            return await dbManager.testConnection();
        } else {
            const result = await query('SELECT NOW() as current_time, version() as pg_version');
            console.log('Connexion à PostgreSQL réussie');

            // Parse the connection string to show config safely (without password)
            const connectionString = config.database.url;
            let configInfo = 'Configuration from connection string';

            if (connectionString.includes('@')) {
                const urlParts = connectionString.split('@')[1];
                const [hostPort, database] = urlParts.split('/');
                const [host, port] = hostPort.split(':');
                configInfo = {
                    host: host,
                    port: port || '5432',
                    database: database || 'postgres',
                    connectionString: connectionString.replace(/:\/\/.*:.*@/, '://***:***@')
                };
            }

            return {
                success: true,
                current_time: result.rows[0].current_time,
                pg_version: result.rows[0].pg_version,
                config: configInfo
            };
        }
    } catch (error) {
        console.error('Erreur de connexion à PostgreSQL:', error);
        return {
            success: false,
            error: error.message
        };
    }
};

// Fonction pour obtenir les statistiques du pool
const getPoolStats = () => {
    if (USE_CLUSTER_MODE) {
        return dbManager.getPoolStats();
    } else {
        return {
            totalCount: pool.totalCount,
            idleCount: pool.idleCount,
            waitingCount: pool.waitingCount
        };
    }
};

// Fonction pour arrêter proprement les connexions
const shutdown = async () => {
    if (USE_CLUSTER_MODE && dbManager) {
        await dbManager.shutdown();
    } else if (pool) {
        await pool.end();
    }
};

module.exports = {
    query,
    getClient,
    pool,
    initDatabase,
    testConnection,
    getPoolStats,
    initializeConnection,
    shutdown
};
