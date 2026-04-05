// Exact replica of the official MoonBit benchmark's Node.js counterpart
var http = require('http')

http.createServer(function (req, res) {
  res.sendDate = false
  res.writeHead(200, {})
  res.end()
}).listen(3006)

console.log('Node.js minimal server on port 3006')
