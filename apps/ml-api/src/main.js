const express = require('express');
const helmet = require('helmet');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8000;

// ==========================================
// 1. Sécurité Applicative (DevSecOps)
// ==========================================
// Helmet configure automatiquement les headers HTTP sécurisés (HSTS, NoSniff, XSS Protection...)
app.use(helmet());
app.use(express.json({ limit: '1mb' })); // Limite la taille des payloads pour éviter les attaques DoS

app.disable('x-powered-by'); // Ne pas exposer publiquement le fait qu'on utilise Express

// ==========================================
// 2. Base de Données (Pure SQL via 'pg')
// ==========================================
// Les identifiants sont injectés uniquement via les variables d'environnement (K8s Secrets)
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
  // En production, on exige une connexion SSL chiffrée avec la DB
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false
});

// ==========================================
// 3. Probes Kubernetes (Liveness & Readiness)
// ==========================================
// Vérifie si le conteneur est en vie (ne fait pas d'appel DB lourd)
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

// Vérifie si l'application est prête à recevoir du trafic (Teste la connexion à Postgres)
app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).send('Ready');
  } catch (error) {
    console.error('Readiness probe failed:', error.message);
    res.status(503).send('Database unavailable');
  }
});

// ==========================================
// 4. API Core (Exemple sécurisé)
// ==========================================
app.post('/api/v1/predict', async (req, res) => {
  const { inputData } = req.body;
  
  if (!inputData) {
    return res.status(400).json({ error: 'Missing inputData' });
  }

  try {
    // SEC-OPS: TOUJOURS utiliser des requêtes paramétrées (Prepared Statements) 
    // pour contrer 100% des attaques par injection SQL. Ne JAMAIS concaténer de chaînes.
    const query = 'INSERT INTO predictions (input_data, status, created_at) VALUES ($1, $2, NOW()) RETURNING id';
    const values = [inputData, 'pending'];
    
    const result = await pool.query(query, values);
    
    res.status(201).json({ 
      message: 'Data queued for ML processing', 
      predictionId: result.rows[0].id 
    });
  } catch (error) {
    console.error('SQL Error:', error.message);
    // Ne jamais renvoyer l'erreur SQL exacte au client (Information Disclosure)
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ==========================================
// 5. Graceful Shutdown (Kubernetes Lifecycle)
// ==========================================
const server = app.listen(PORT, () => {
  console.log(`🚀 ML API Server running on port ${PORT}`);
});

const gracefulShutdown = () => {
  console.log('⏳ Received kill signal (SIGTERM/SIGINT). Shutting down gracefully...');
  
  // 1. On arrête d'accepter de nouvelles requêtes
  server.close(() => {
    console.log('🛑 HTTP server closed.');
    
    // 2. On ferme proprement le pool de connexions SQL
    pool.end(() => {
      console.log('🐘 Database connections closed.');
      process.exit(0);
    });
  });

  // Force l'arrêt après 10 secondes si certaines requêtes bloquent
  setTimeout(() => {
    console.error('💀 Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', gracefulShutdown); // Signal utilisé par Kubernetes
process.on('SIGINT', gracefulShutdown);  // Signal utilisé par Ctrl+C en local
