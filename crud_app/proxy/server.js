const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3001;

// Configuration du load balancer interne
const INTERNAL_LB_URL = process.env.INTERNAL_LB_URL || 'http://private-load-balancer.internal';

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        server: require('os').hostname(),
        proxy_target: INTERNAL_LB_URL
    });
});

// Proxy endpoint pour récupérer les infos du backend
app.get('/backend-info', async (req, res) => {
    try {
        console.log(`Proxying request to: ${INTERNAL_LB_URL}/info`);

        const response = await axios.get(`${INTERNAL_LB_URL}/info`, {
            timeout: 10000,
            headers: {
                'User-Agent': 'API-Proxy/1.0'
            }
        });

        console.log('Backend response received:', response.status);

        // Ajouter des métadonnées du proxy
        const proxyData = {
            ...response.data,
            proxy_info: {
                proxy_server: require('os').hostname(),
                proxy_timestamp: new Date().toISOString(),
                target_url: `${INTERNAL_LB_URL}/info`,
                response_time_ms: Date.now() - req.start_time
            }
        };

        res.json(proxyData);

    } catch (error) {
        console.error('Error proxying to backend:', error.message);

        const errorResponse = {
            error: true,
            message: 'Failed to reach backend services',
            details: error.message,
            proxy_info: {
                proxy_server: require('os').hostname(),
                proxy_timestamp: new Date().toISOString(),
                target_url: `${INTERNAL_LB_URL}/info`,
                error_type: error.code || 'UNKNOWN'
            }
        };

        // Différents codes d'erreur selon le type
        if (error.code === 'ECONNREFUSED') {
            res.status(502).json(errorResponse);
        } else if (error.code === 'ETIMEDOUT') {
            res.status(504).json(errorResponse);
        } else {
            res.status(500).json(errorResponse);
        }
    }
});

// Middleware pour mesurer le temps de réponse
app.use((req, res, next) => {
    req.start_time = Date.now();
    next();
});

// Proxy générique pour d'autres endpoints du backend
app.use('*', async (req, res) => {
    try {
        const backendPath = req.path;
        const targetUrl = `${INTERNAL_LB_URL}${backendPath}`;

        console.log(`Proxying ${req.method} request to: ${targetUrl}`);

        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: {
                ...req.headers,
                'host': undefined,
                'User-Agent': 'API-Proxy/1.0'
            },
            timeout: 10000
        });

        res.status(response.status).json(response.data);

    } catch (error) {
        console.error('Error in generic proxy:', error.message);
        res.status((error.response && error.response.status) || 500).json({
            error: true,
            message: 'Proxy error',
            details: error.message
        });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`API Proxy server running on port ${PORT}`);
    console.log(`Proxying to: ${INTERNAL_LB_URL}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});
