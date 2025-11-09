const express = require('express');
const cors = require('cors');
const { config, validateConfig } = require('./config');
const { query, initDatabase, testConnection, getPoolStats, initializeConnection, shutdown } = require('./database');

// Valider la configuration au démarrage
try {
    validateConfig();
} catch (error) {
    console.error('Erreur de configuration:', error.message);
    process.exit(1);
}

const app = express();
const PORT = config.server.port;

// Initialize database connection
let serverInstance = null;

// Database connection and schema initialization will be performed in
// the `bootstrap` function near the end of this file, so the HTTP server
// only starts after DB is ready.

// // Middleware
// if (config.app.enableCors) {
//     const corsOptions = {
//         origin: config.app.corsOrigins,
//         credentials: true
//     };
//     app.use(cors());
// }

app.use(cors());
app.use(express.json({ limit: config.app.requestLimit }));

// Basic logging middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.url}`);
    next();
});

// Routes
app.get('/', (req, res) => {
    res.json({
        message: 'CRUD App Backend API',
        version: config.deployment.deploymentVersion,
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: config.deployment.environment,
        deployment: {
            version: config.deployment.deploymentVersion,
            date: config.deployment.deploymentDate,
            instanceId: config.deployment.instanceId
        }
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        version: process.version
    });
});

// Database health check endpoint
app.get('/health/database', async (req, res) => {
    try {
        const dbStatus = await testConnection();
        const poolStats = getPoolStats();

        res.json({
            database: dbStatus,
            pool: poolStats,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Database health check failed',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// ============================================================================
// DATABASE TEST ENDPOINTS
// ============================================================================

// Initialize database tables
app.post('/db/init', async (req, res) => {
    try {
        await initDatabase();
        res.json({
            success: true,
            message: 'Database tables initialized successfully',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: 'Failed to initialize database',
            message: error.message
        });
    }
});

// Test database connection
app.get('/db/test', async (req, res) => {
    try {
        const result = await testConnection();
        res.json(result);
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================================================
// WRITE OPERATIONS (CREATE/INSERT/UPDATE)
// ============================================================================

// Create a new user (INSERT test)
app.post('/db/users', async (req, res) => {
    try {
        const { name, email } = req.body;

        if (!name || !email) {
            return res.status(400).json({
                error: 'Name and email are required'
            });
        }

        const result = await query(
            'INSERT INTO test_users (name, email) VALUES ($1, $2) RETURNING *',
            [name, email]
        );

        res.status(201).json({
            success: true,
            user: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        if (error.code === '23505') { // Unique violation
            res.status(409).json({
                error: 'Email already exists',
                message: error.detail
            });
        } else {
            res.status(500).json({
                error: 'Failed to create user',
                message: error.message
            });
        }
    }
});

// Update a user (UPDATE test)
app.put('/db/users/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, email } = req.body;

        const result = await query(
            'UPDATE test_users SET name = $1, email = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
            [name, email, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: 'User not found'
            });
        }

        res.json({
            success: true,
            user: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to update user',
            message: error.message
        });
    }
});

// Add log entry (INSERT test)
app.post('/db/logs', async (req, res) => {
    try {
        const { message, level = 'INFO' } = req.body;

        if (!message) {
            return res.status(400).json({
                error: 'Message is required'
            });
        }

        const result = await query(
            'INSERT INTO test_logs (message, level) VALUES ($1, $2) RETURNING *',
            [message, level]
        );

        res.status(201).json({
            success: true,
            log: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to create log entry',
            message: error.message
        });
    }
});

// Bulk insert users (BATCH INSERT test)
app.post('/db/users/bulk', async (req, res) => {
    try {
        const { users } = req.body;

        if (!users || !Array.isArray(users)) {
            return res.status(400).json({
                error: 'Users array is required'
            });
        }

        const results = [];
        for (const user of users) {
            const { name, email } = user;
            if (name && email) {
                try {
                    const result = await query(
                        'INSERT INTO test_users (name, email) VALUES ($1, $2) RETURNING *',
                        [name, email]
                    );
                    results.push(result.rows[0]);
                } catch (error) {
                    results.push({ error: error.message, name, email });
                }
            }
        }

        res.status(201).json({
            success: true,
            results: results,
            count: results.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to bulk insert users',
            message: error.message
        });
    }
});

// ============================================================================
// READ OPERATIONS (SELECT)
// ============================================================================

// Get all users (SELECT test)
app.get('/db/users', async (req, res) => {
    try {
        const { limit = 100, offset = 0 } = req.query;

        const result = await query(
            'SELECT * FROM test_users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
            [limit, offset]
        );

        const countResult = await query('SELECT COUNT(*) FROM test_users');
        const totalCount = parseInt(countResult.rows[0].count);

        res.json({
            success: true,
            users: result.rows,
            pagination: {
                total: totalCount,
                limit: parseInt(limit),
                offset: parseInt(offset),
                hasMore: (parseInt(offset) + parseInt(limit)) < totalCount
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to fetch users',
            message: error.message
        });
    }
});

// Get user by ID (SELECT with WHERE)
app.get('/db/users/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await query(
            'SELECT * FROM test_users WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: 'User not found'
            });
        }

        res.json({
            success: true,
            user: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to fetch user',
            message: error.message
        });
    }
});

// Search users by name (SELECT with LIKE)
app.get('/db/users/search/:term', async (req, res) => {
    try {
        const { term } = req.params;

        const result = await query(
            'SELECT * FROM test_users WHERE name ILIKE $1 OR email ILIKE $1 ORDER BY created_at DESC',
            [`%${term}%`]
        );

        res.json({
            success: true,
            users: result.rows,
            searchTerm: term,
            count: result.rows.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to search users',
            message: error.message
        });
    }
});

// Get all logs (SELECT test)
app.get('/db/logs', async (req, res) => {
    try {
        const { limit = 50, level } = req.query;

        let queryText = 'SELECT * FROM test_logs';
        let params = [];

        if (level) {
            queryText += ' WHERE level = $1';
            params.push(level);
            queryText += ' ORDER BY created_at DESC LIMIT $2';
            params.push(limit);
        } else {
            queryText += ' ORDER BY created_at DESC LIMIT $1';
            params.push(limit);
        }

        const result = await query(queryText, params);

        res.json({
            success: true,
            logs: result.rows,
            count: result.rows.length,
            filters: { level },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to fetch logs',
            message: error.message
        });
    }
});

// Get database statistics (SELECT with aggregations)
app.get('/db/stats', async (req, res) => {
    try {
        const usersCountResult = await query('SELECT COUNT(*) as count FROM test_users');
        const logsCountResult = await query('SELECT COUNT(*) as count FROM test_logs');
        const logLevelsResult = await query(
            'SELECT level, COUNT(*) as count FROM test_logs GROUP BY level ORDER BY count DESC'
        );
        const recentUsersResult = await query(
            'SELECT COUNT(*) as count FROM test_users WHERE created_at > NOW() - INTERVAL \'24 hours\''
        );

        res.json({
            success: true,
            statistics: {
                users: {
                    total: parseInt(usersCountResult.rows[0].count),
                    recent24h: parseInt(recentUsersResult.rows[0].count)
                },
                logs: {
                    total: parseInt(logsCountResult.rows[0].count),
                    byLevel: logLevelsResult.rows
                }
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to fetch statistics',
            message: error.message
        });
    }
});

// ============================================================================
// DELETE OPERATIONS (for cleanup)
// ============================================================================

// Delete user by ID
app.delete('/db/users/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await query(
            'DELETE FROM test_users WHERE id = $1 RETURNING *',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: 'User not found'
            });
        }

        res.json({
            success: true,
            deletedUser: result.rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to delete user',
            message: error.message
        });
    }
});

// Clear all test data (TRUNCATE)
app.delete('/db/clear', async (req, res) => {
    try {
        await query('TRUNCATE test_users, test_logs RESTART IDENTITY');

        res.json({
            success: true,
            message: 'All test data cleared',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to clear test data',
            message: error.message
        });
    }
});

// Get server info including IP
app.get('/info', (req, res) => {
    const os = require('os');
    const networkInterfaces = os.networkInterfaces();
    const ips = [];

    Object.keys(networkInterfaces).forEach(interface => {
        networkInterfaces[interface].forEach(details => {
            if (details.family === 'IPv4' && !details.internal) {
                ips.push(details.address);
            }
        });
    });

    res.json({
        hostname: os.hostname(),
        platform: os.platform(),
        architecture: os.arch(),
        ips: ips,
        clientIp: req.ip || req.connection.remoteAddress,
        headers: req.headers,
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(`Error: ${err.message}`);
    res.status(500).json({ error: 'Internal server error' });
});


// Bootstrap: initialize DB (connection + schema) then start the HTTP server.
const bootstrap = async () => {
    try {
        await initializeConnection();
        console.log('[App] Database connection initialized');

        // Initialize tables / seeds
        await initDatabase();
        console.log('[App] Database schema and seeds initialized');
    } catch (error) {
        console.error('[App] Failed to initialize application:', error);
        process.exit(1);
    }

    serverInstance = app.listen(PORT, config.server.host, () => {
        console.log(`========================================`);
        console.log(`🚀 Server running on ${config.server.host}:${PORT}`);
        console.log(`📱 Environment: ${config.deployment.environment}`);
        console.log(`📦 Version: ${config.deployment.deploymentVersion}`);
        console.log(`🗄️  Database: Connected to PostgreSQL cluster`);
        console.log(`📅 Deployed: ${config.deployment.deploymentDate}`);
        console.log(`🆔 Instance: ${config.deployment.instanceId}`);
        console.log(`🌐 API endpoints available at http://${config.server.host}:${PORT}/`);
        console.log(`========================================`);
    });
};

// Start bootstrap sequence
bootstrap();

// Graceful shutdown
const gracefulShutdown = async (signal) => {
    console.log(`\n[App] Received ${signal}, shutting down gracefully...`);

    // Stop accepting new connections
    if (serverInstance) {
        serverInstance.close(() => {
            console.log('[App] HTTP server closed');
        });
    }

    // Close database connections
    try {
        await shutdown();
        console.log('[App] Database connections closed');
    } catch (error) {
        console.error('[App] Error closing database connections:', error);
    }

    process.exit(0);
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
