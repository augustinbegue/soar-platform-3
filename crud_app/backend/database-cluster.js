const { Pool } = require('pg');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

/**
 * PostgreSQL Cluster Connection Manager
 * 
 * This module manages connections to a PostgreSQL cluster running with Patroni.
 * It automatically discovers PostgreSQL instances using AWS EC2 API, identifies
 * the master node using Patroni's REST API, and reconnects if the master fails.
 */

class PostgreSQLClusterManager {
  constructor(config) {
    this.config = {
      region: config.region || process.env.AWS_REGION || 'eu-west-1',
      database: config.database || 'postgres',
      user: config.user || 'admin',
      password: config.password || 'admin123',
      port: config.port || 5432,
      patroniPort: config.patroniPort || 8008,
      // Pool configuration
      max: config.max || 20,
      idleTimeoutMillis: config.idleTimeoutMillis || 30000,
      connectionTimeoutMillis: config.connectionTimeoutMillis || 10000,
      maxUses: config.maxUses || 7500,
      // Discovery configuration
      discoveryInterval: config.discoveryInterval || 30000, // 30 seconds
      healthCheckInterval: config.healthCheckInterval || 10000, // 10 seconds
      maxRetries: config.maxRetries || 3,
      retryDelay: config.retryDelay || 2000,
      // Tags for instance filtering
      instanceTags: config.instanceTags || {
        Role: 'postgresql-patroni',
        Tier: 'database'
      }
    };

    this.pool = null;
    this.currentMasterIp = null;
    this.clusterInstances = [];
    this.discoveryTimer = null;
    this.healthCheckTimer = null;
    this.isShuttingDown = false;
    this.reconnecting = false;
  }

  /**
   * Initialize the cluster manager
   */
  async initialize() {
    console.log('[DB Cluster] Initializing PostgreSQL cluster connection manager...');

    try {
      // Discover instances
      await this.discoverInstances();

      if (this.clusterInstances.length === 0) {
        throw new Error('No PostgreSQL instances found in the cluster');
      }

      // Find and connect to master
      await this.findAndConnectToMaster();

      // Start background tasks
      this.startDiscoveryTimer();
      this.startHealthCheckTimer();

      console.log('[DB Cluster] Cluster manager initialized successfully');
      return true;
    } catch (error) {
      console.error('[DB Cluster] Failed to initialize:', error);
      throw error;
    }
  }

  /**
   * Discover PostgreSQL instances using AWS CLI
   */
  async discoverInstances() {
    console.log('[DB Cluster] Discovering PostgreSQL instances...');

    try {
      // Build filter expression for tags
      const filters = Object.entries(this.config.instanceTags)
        .map(([key, value]) => `Name=tag:${key},Values=${value}`)
        .join(' ');

      // Query EC2 for instances with specific tags
      const command = `aws ec2 describe-instances \
        --region ${this.config.region} \
        --filters "Name=instance-state-name,Values=running" ${filters} \
        --query 'Reservations[].Instances[].PrivateIpAddress' \
        --output json`;

      const { stdout, stderr } = await execAsync(command);

      if (stderr) {
        console.warn('[DB Cluster] AWS CLI warnings:', stderr);
      }

      const ips = JSON.parse(stdout.trim()).filter(ip => ip && ip !== 'None');

      if (ips.length === 0) {
        console.warn('[DB Cluster] No running PostgreSQL instances found');
        return [];
      }

      this.clusterInstances = ips;
      console.log(`[DB Cluster] Discovered ${ips.length} instances:`, ips);

      return ips;
    } catch (error) {
      console.error('[DB Cluster] Failed to discover instances:', error.message);
      // Don't throw - keep using existing instances if discovery fails
      return this.clusterInstances;
    }
  }

  /**
   * Check if a PostgreSQL instance is the master using Patroni REST API
   */
  async checkIfMaster(ip) {
    try {
      const http = require('http');

      return new Promise((resolve, reject) => {
        const options = {
          hostname: ip,
          port: this.config.patroniPort,
          path: '/master',
          method: 'GET',
          timeout: 5000
        };

        const req = http.request(options, (res) => {
          if (res.statusCode === 200) {
            resolve(true);
          } else {
            resolve(false);
          }
        });

        req.on('error', () => {
          resolve(false);
        });

        req.on('timeout', () => {
          req.destroy();
          resolve(false);
        });

        req.end();
      });
    } catch (error) {
      return false;
    }
  }

  /**
   * Find the master node from the cluster
   */
  async findMaster() {
    console.log('[DB Cluster] Searching for master node...');

    for (const ip of this.clusterInstances) {
      const isMaster = await this.checkIfMaster(ip);
      if (isMaster) {
        console.log(`[DB Cluster] Found master at ${ip}`);
        return ip;
      }
    }

    console.warn('[DB Cluster] No master found, using first available instance');
    return this.clusterInstances[0];
  }

  /**
   * Create a new connection pool to the specified host
   */
  createPool(host) {
    const poolConfig = {
      host: host,
      port: this.config.port,
      database: this.config.database,
      user: this.config.user,
      password: this.config.password,
      max: this.config.max,
      idleTimeoutMillis: this.config.idleTimeoutMillis,
      connectionTimeoutMillis: this.config.connectionTimeoutMillis,
      maxUses: this.config.maxUses,
      ssl: false
    };

    const pool = new Pool(poolConfig);

    // Handle pool errors
    pool.on('error', (err, client) => {
      console.error('[DB Cluster] Pool error:', err);
      if (!this.reconnecting && !this.isShuttingDown) {
        this.handleConnectionLoss();
      }
    });

    return pool;
  }

  /**
   * Connect to the master node
   */
  async findAndConnectToMaster() {
    let retries = 0;

    while (retries < this.config.maxRetries) {
      try {
        const masterIp = await this.findMaster();

        if (!masterIp) {
          throw new Error('No master node available');
        }

        // Close existing pool if any
        if (this.pool) {
          await this.pool.end();
        }

        // Create new pool
        this.pool = this.createPool(masterIp);
        this.currentMasterIp = masterIp;

        // Test the connection
        const result = await this.pool.query('SELECT NOW(), pg_is_in_recovery()');
        const isInRecovery = result.rows[0].pg_is_in_recovery;

        if (isInRecovery) {
          console.warn(`[DB Cluster] Connected to ${masterIp} but it's in recovery mode`);
          throw new Error('Connected node is not a master');
        }

        console.log(`[DB Cluster] Successfully connected to master at ${masterIp}`);
        return true;
      } catch (error) {
        retries++;
        console.error(`[DB Cluster] Connection attempt ${retries} failed:`, error.message);

        if (retries < this.config.maxRetries) {
          console.log(`[DB Cluster] Retrying in ${this.config.retryDelay}ms...`);
          await new Promise(resolve => setTimeout(resolve, this.config.retryDelay));
        } else {
          throw new Error(`Failed to connect to master after ${this.config.maxRetries} attempts`);
        }
      }
    }
  }

  /**
   * Handle connection loss and reconnect
   */
  async handleConnectionLoss() {
    if (this.reconnecting || this.isShuttingDown) {
      return;
    }

    this.reconnecting = true;
    console.log('[DB Cluster] Connection lost, attempting to reconnect...');

    try {
      // Rediscover instances
      await this.discoverInstances();

      // Find and connect to new master
      await this.findAndConnectToMaster();

      console.log('[DB Cluster] Reconnection successful');
    } catch (error) {
      console.error('[DB Cluster] Reconnection failed:', error);
      // Will retry on next health check
    } finally {
      this.reconnecting = false;
    }
  }

  /**
   * Start periodic instance discovery
   */
  startDiscoveryTimer() {
    this.discoveryTimer = setInterval(async () => {
      if (!this.isShuttingDown) {
        await this.discoverInstances();
      }
    }, this.config.discoveryInterval);
  }

  /**
   * Start periodic health checks
   */
  startHealthCheckTimer() {
    this.healthCheckTimer = setInterval(async () => {
      if (this.isShuttingDown || this.reconnecting) {
        return;
      }

      try {
        // Check if current connection is still to the master
        if (this.currentMasterIp) {
          const isMaster = await this.checkIfMaster(this.currentMasterIp);
          if (!isMaster) {
            console.warn('[DB Cluster] Current node is no longer the master');
            await this.handleConnectionLoss();
          }
        }
      } catch (error) {
        console.error('[DB Cluster] Health check failed:', error.message);
      }
    }, this.config.healthCheckInterval);
  }

  /**
   * Execute a query
   */
  async query(text, params) {
    if (!this.pool) {
      throw new Error('Database pool not initialized');
    }

    const start = Date.now();
    try {
      const res = await this.pool.query(text, params);
      const duration = Date.now() - start;
      console.log(`[DB Cluster] Query executed in ${duration}ms`);
      return res;
    } catch (error) {
      console.error('[DB Cluster] Query error:', error.message);

      // If connection error, try to reconnect
      if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT' || error.code === 'ECONNRESET') {
        await this.handleConnectionLoss();
      }

      throw error;
    }
  }

  /**
   * Get a client from the pool
   */
  async getClient() {
    if (!this.pool) {
      throw new Error('Database pool not initialized');
    }
    return await this.pool.connect();
  }

  /**
   * Get pool statistics
   */
  getPoolStats() {
    if (!this.pool) {
      return null;
    }

    return {
      totalCount: this.pool.totalCount,
      idleCount: this.pool.idleCount,
      waitingCount: this.pool.waitingCount,
      currentMaster: this.currentMasterIp,
      clusterSize: this.clusterInstances.length,
      clusterInstances: this.clusterInstances
    };
  }

  /**
   * Test connection
   */
  async testConnection() {
    try {
      const result = await this.query('SELECT NOW() as current_time, version() as pg_version, pg_is_in_recovery() as is_replica');

      return {
        success: true,
        current_time: result.rows[0].current_time,
        pg_version: result.rows[0].pg_version,
        is_replica: result.rows[0].is_replica,
        master_ip: this.currentMasterIp,
        cluster_instances: this.clusterInstances
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Shutdown the cluster manager
   */
  async shutdown() {
    console.log('[DB Cluster] Shutting down cluster manager...');
    this.isShuttingDown = true;

    // Clear timers
    if (this.discoveryTimer) {
      clearInterval(this.discoveryTimer);
    }
    if (this.healthCheckTimer) {
      clearInterval(this.healthCheckTimer);
    }

    // Close pool
    if (this.pool) {
      await this.pool.end();
    }

    console.log('[DB Cluster] Cluster manager shut down');
  }
}

module.exports = { PostgreSQLClusterManager };
