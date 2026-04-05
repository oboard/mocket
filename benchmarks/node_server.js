// Node.js HTTP benchmark server - minimal, no framework overhead
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/text') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Hello, World!');
  } else if (req.url === '/json') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: 'Hello, World!' }));
  } else if (req.url && req.url.startsWith('/user/')) {
    const id = req.url.slice(6);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ id: parseInt(id), name: 'User ' + id }));
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(3002, () => {
  console.log('Node.js server listening on port 3002');
});
