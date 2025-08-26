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

// Routes (with detailed error handling)
try {
  console.log('Loading cashfree routes...');
  const cashfreeRoutes = require('./routes/cashfree');
  app.use('/api/cashfree', cashfreeRoutes);
  console.log('✅ Cashfree routes loaded successfully');
} catch (error) {
  console.error('❌ Error loading cashfree routes:', error.message);
  app.get('/api/cashfree/*', (req, res) => {
    res.status(500).json({ 
      error: 'Cashfree routes not loaded',
      details: error.message 
    });
  });
}

try {
  console.log('Loading webhook routes...');
  const webhookRoutes = require('./routes/webhook');
  app.use('/api/webhook', webhookRoutes);
  console.log('✅ Webhook routes loaded successfully');
} catch (error) {
  console.error('❌ Error loading webhook routes:', error.message);
  app.get('/api/webhook/*', (req, res) => {
    res.status(500).json({ 
      error: 'Webhook routes not loaded',
      details: error.message 
    });
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
