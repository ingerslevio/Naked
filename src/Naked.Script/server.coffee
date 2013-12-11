path = require 'path'
express = require('express')
app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server, {'log level': 1})
port = 8181
_ = require('underscore')
build = require('consolidate-build')

app.use(express.bodyParser())

server.listen(port)

app.get '/', (req, res) ->
  res.send """
          <!DOCTYPE html>
          <html>
          <head>
            <script src="/socket.io/socket.io.js"></script>
            <script src="/reloader.js"></script>
          </head>
          <body>
          </body>
          </html>
          """

app.get '/reloader.js', (req, res) ->
  res.setHeader('Content-Type', 'text/javascript');
  res.send  """
            var socket = io.connect('http://localhost:#{port}');
            socket.on('file', function (data) {
              if(data.type === 'initial') {
                if(console && console.log) { console.log("Connection reset, probably because reloader is restarted."); }
              } 
              else if(data.type === 'css') {
                if(console && console.log) { console.log("Change on " + data.file + ". Reloading stylesheets."); }
                var links = document.getElementsByTagName('link');
                for(var i=0; i<links.length; i++) {
                  var link = links[ i ];
                  if ( typeof link.rel != 'string' || link.rel.length === 0 || link.rel === 'stylesheet' ) {
                    var href = link.getAttribute('href').split('?')[0];
                    link.setAttribute('href', href + "?t=" + new Date().getTime());
                  }
                }
              } 
              else {
                if(console && console.log) { console.log("Change on " + data.file + ". Reloading page."); }
                window.location.reload()
              }
            });
            """

app.get '/trigger/:file', (req, res) ->
  file = req.params.file.replace(/\;/ig, "\\")
  console.log "Got change on #{file}. Pushing info to clients."

  extension = path.extname(file)[1..]
  builder = _.find(build, (x) -> x.inExtension is extension)
  outExtension = builder?.outExtension ? extension

  io.sockets.emit 'file', 
    file: file
    type: outExtension
  res.send {success: true}


io.sockets.on 'connection', (socket) ->
  socket.emit 'file', type: 'initial'