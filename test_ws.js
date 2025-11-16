const ws = new WebSocket('ws://localhost:8080/ws');
ws.addEventListener('open', () => {
  console.log('connected');
  ws.send('hello mocket');
});
ws.addEventListener('message', (ev) => {
  console.log('echo:', ev.data);
  ws.close();
});
ws.addEventListener('close', () => console.log('closed'));
ws.addEventListener('error', (err) => console.log('error', err));