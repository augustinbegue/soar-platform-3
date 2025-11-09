// Configuration centralisée pour toutes les variables d'environnement
require('dotenv').config();

const config = {
    // Server Configuration
    server: {
        port: process.env.PORT || 3001,
        nodeEnv: process.env.NODE_ENV || 'development',
        host: process.env.HOST || '0.0.0.0'
    },

    // Database Configuration
    database: {
        url: process.env.DATABASE_URL || 'postgresql://admin:admin123@localhost:5432/postgres',
        useCluster: process.env.DATABASE_USE_CLUSTER !== 'false', // Default to true in production
        region: process.env.AWS_REGION || process.env.DATABASE_REGION || 'eu-west-1',
        poolConfig: {
            max: parseInt(process.env.DB_POOL_MAX) || 20,
            idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
            connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 10000,
            maxUses: parseInt(process.env.DB_MAX_USES) || 7500
        }
    },

    // Application Configuration
    app: {
        logLevel: process.env.LOG_LEVEL || 'info',
        enableCors: process.env.ENABLE_CORS !== 'false',
        corsOrigins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['*'],
        requestLimit: process.env.REQUEST_LIMIT || '10mb',
        enableHealthChecks: process.env.ENABLE_HEALTH_CHECKS !== 'false'
    },

    // Security Configuration
    security: {
        enableRateLimit: process.env.ENABLE_RATE_LIMIT === 'true',
        rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX) || 100,
        rateLimitWindow: parseInt(process.env.RATE_LIMIT_WINDOW) || 15 * 60 * 1000, // 15 minutes
        trustProxy: process.env.TRUST_PROXY === 'true'
    },

    // Deployment Configuration
    deployment: {
        instanceId: process.env.INSTANCE_ID || 'unknown',
        deploymentVersion: process.env.DEPLOYMENT_VERSION || '1.0.0',
        deploymentDate: process.env.DEPLOYMENT_DATE || new Date().toISOString(),
        environment: process.env.ENVIRONMENT || 'local'
    }
};

// Validation des variables critiques
const validateConfig = () => {
    const requiredVars = [];

    if (!config.database.url) {
        requiredVars.push('DATABASE_URL');
    }

    if (requiredVars.length > 0) {
        throw new Error(`Variables d'environnement manquantes: ${requiredVars.join(', ')}`);
    }

    console.log(`Configuration chargée pour l'environnement: ${config.deployment.environment}`);
    console.log(`Version du déploiement: ${config.deployment.deploymentVersion}`);
    console.log(`Port d'écoute: ${config.server.port}`);
};

module.exports = { config, validateConfig };
