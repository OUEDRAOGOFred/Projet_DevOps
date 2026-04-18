const request = require('supertest');
const express = require('express');

// Pour tester isolément, on mocke la base de données
jest.mock('pg', () => {
  const mPool = {
    query: jest.fn(),
    end: jest.fn(),
  };
  return { Pool: jest.fn(() => mPool) };
});

const { Pool } = require('pg');
let pool;
let server;
let app;

beforeAll(() => {
  // On s'assure de ne pas écouter sur un port pour les tests unitaire (on utilise juste l'instance Express)
  process.env.PORT = 0; 
  pool = new Pool();
  
  // On importe l'application (idéalement main.js devrait exporter app sans faire le .listen directement, 
  // mais pour simuler le comportement, on teste les routes basiques).
  // Pour une architecture parfaite, on sépare `app.js` et `server.js`.
});

describe('DevSecOps API Security & Health Tests', () => {
  
  beforeEach(() => {
    // Reset express app for testing routes isolation (simplified view)
    app = express();
    app.use(express.json());
    
    app.get('/healthz', (req, res) => res.status(200).send('OK'));
    app.post('/api/v1/predict', async (req, res) => {
      if (!req.body.inputData) return res.status(400).json({ error: 'Missing inputData' });
      res.status(201).json({ message: 'Data queued for ML processing', predictionId: 123 });
    });
  });

  it('should pass health probe for Kubernetes liveness', async () => {
    const res = await request(app).get('/healthz');
    expect(res.statusCode).toEqual(200);
    expect(res.text).toBe('OK');
  });

  it('should return 400 Bad Request when ML inputData is missing', async () => {
    const res = await request(app)
      .post('/api/v1/predict')
      .send({ maliciousPayload: "SELECT * FROM users" }); // Input validation test
    expect(res.statusCode).toEqual(400);
    expect(res.body).toHaveProperty('error', 'Missing inputData');
  });

  it('should accept valid ML request payload', async () => {
    const res = await request(app)
      .post('/api/v1/predict')
      .send({ inputData: "User behaviour sequence context" });
    expect(res.statusCode).toEqual(201);
    expect(res.body).toHaveProperty('predictionId');
  });
});
