var net = require('net');

var server = net.createServer(function(socket) {
	socket.on('error', function (_) {});
	socket.pipe(socket);
});

server.listen(4201, '127.0.0.1');
