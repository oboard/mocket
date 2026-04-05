// Express.js benchmark server - with framework routing
const express = require('express');
const app = express();

app.get('/text', (req, res) => {
  res.type('text/plain').send('Hello, World!');
});

app.get('/json', (req, res) => {
  res.json({ message: 'Hello, World!' });
});

app.get('/user/:id', (req, res) => {
  res.json({ id: parseInt(req.params.id), name: 'User ' + req.params.id });
});

app.listen(3003, () => {
  console.log('Express server listening on port 3003');
});
