const express = require('express');
const cors = require('cors');

// Load environment variables (don't fail if .env doesn't exist)
try {
  require('dotenv').config();
} catch (error) {
  console.log('No .env file found, using environment variables');
}

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Basic route for testing
app.get('/', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Cashfree Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Cashfree Backend is running',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Routes (with error handling)
try {
  app.use('/api/cashfree', require('./routes/cashfree'));
  app.use('/api/webhook', require('./routes/webhook'));
} catch (error) {
  console.error('Error loading routes:', error);
  app.get('/api/*', (req, res) => {
    res.status(500).json({ error: 'Routes not loaded properly' });
  });
}

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: error.message 
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
});

module.exports = app;
