_       = require "underscore"
express = require "express"
http    = require "http"
socket  = require "socket.io"

app    = express()
server = http.createServer app
io     = socket.listen server
#io.set "transports", ["xhr-polling"]

app.use express.bodyParser()
app.use express.static(__dirname + "/public")

# Sockets code

sockets = []
latestPositions = {}
latestPositionTime = new Date
latestPosition     = null
latestTimeout      = 4*60*60*1000 # 4 hours..

timeoutPositions = ->
  keys = []

  _.each latestPositions, ({position, time}, key) ->
    keys.push key unless (new Date) - time > latestTimeout

  latestPositions = _.pick latestPositions, keys

io.sockets.on "connection", (socket) ->
  sockets.push socket

  socket.on "disconnect", ->
    sockets = _.without sockets, socket

  timeoutPositions()

  _.each latestPositions, ({position}, name) ->
    socket.emit "position", position, name

sendPosition = (position, name) ->
  if (position.timestamp || position.recorded_at)
    timestamp = new Date(position.timestamp || position.recorded_at)
  else
    timestamp = new Date

  return if latestPositions[name] && timestamp < latestPositions[name].time

  latestPositions[name] = {
    time:     timestamp,
    position: position
  }

  _.each sockets, (socket) ->
    socket.emit "position", position, name

clearPosition = (name) ->
  delete latestPositions[name]

  _.each sockets, (socket) ->
    socket.emit "clear", name

app.post "/report", (req, res) ->
  console.log "got position", req.body
  _.defer sendPosition, req.body.location, req.body.name
  res.end "Thanks brah!"

app.post "/clear", (req, res) ->
  console.log "clearing position", req.body
  _.defer clearPosition, req.body.name
  res.end "Thanks brah!"

port = Number(process.env.PORT || 5000)
server.listen port, ->
    console.log "here we go!"
