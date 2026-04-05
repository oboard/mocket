var http = require('http')

http.createServer(function (req, res) {
  res.sendDate = false
  res.writeHead(200, {})
  res.end()
}).listen(3002)
