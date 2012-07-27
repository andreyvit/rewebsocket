assert = require 'assert'

wsio = require 'websocket.io'
http = require 'http'
Url  = require 'url'
fs   = require 'fs'

PORT = 43217

LISTEN_GRACE_PERIOD = 200
TEST_RECONNECTION_INTERVAL = 200

WebSocket   = require 'ws'
ReWebSocket = require('../lib/rewebsocket')(WebSocket)


describe "ReWebSocket", ->

  it "should connect to a server", (done) ->
    server = wsio.listen(PORT)
    await setTimeout defer(), LISTEN_GRACE_PERIOD

    outgoing = new ReWebSocket("ws://127.0.0.1:#{PORT}")

    # connect
    await
        server.on 'connection', defer(incoming)
        outgoing.onconnecting = defer()
        outgoing.onopen = defer()
        outgoing.open()

    # send
    await
        incoming.once 'message', defer(message)
        outgoing.send "Hello"
    assert.equal message, "Hello"

    # receive
    await
        outgoing.onmessage = defer(event)
        incoming.send "World"
    assert.equal event.data, "World"

    # disconnect
    await
        outgoing.onclose = defer()
        incoming.once 'close', defer()
        outgoing.close()

    server.httpServer.close()
    done()


  it "should reconnect when the connection is lost", (done) ->
    server = wsio.listen(PORT)
    await setTimeout defer(), LISTEN_GRACE_PERIOD

    outgoing = new ReWebSocket("ws://127.0.0.1:#{PORT}")
    outgoing.reconnectIntervals = [TEST_RECONNECTION_INTERVAL]

    # connect
    await
        server.on 'connection', defer(incoming)
        outgoing.onopen = defer()
        outgoing.open()

    # send
    await
        incoming.once 'message', defer(message)
        outgoing.send "Hello"
    assert.equal message, "Hello"

    # server closes connection
    await
        outgoing.onclose = defer()
        incoming.close()

    # reconnection
    before = +new Date()
    await
        server.on 'connection', defer(incoming)
        outgoing.onopen = defer()
    delay = (+new Date() - before)
    assert.ok delay >   TEST_RECONNECTION_INTERVAL
    assert.ok delay < 2*TEST_RECONNECTION_INTERVAL

    # send
    await
        incoming.once 'message', defer(message)
        outgoing.send "Hello"
    assert.equal message, "Hello"

    # disconnect
    await
        outgoing.onclose = defer()
        incoming.once 'close', defer()
        outgoing.close()

    server.httpServer.close()
    done()


  it "should emit close event with previousReadyState = CONNECTING when connection fails", (done) ->
    outgoing = new ReWebSocket("ws://127.0.0.1:#{PORT}")
    outgoing.reconnectInterval = TEST_RECONNECTION_INTERVAL

    await
        outgoing.onclose = defer(event)
        outgoing.open()

    assert.equal event.previousReadyState, ReWebSocket.CONNECTING
    outgoing.close()
    done()
