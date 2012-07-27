debug = require('debug')('rewebsocket')

wait = (timeout, func) -> setTimeout(func, timeout)

module.exports = (WebSocket) ->

  # based on: https://github.com/joewalnes/reconnecting-websocket
  class ReWebSocket

    @CONNECTING = WebSocket.CONNECTING
    @OPEN       = WebSocket.OPEN
    @CLOSED     = WebSocket.CLOSED


    constructor: (@url, @protocols) ->
      @URL = @url

      @reconnectIntervals = [10, 100, 500, 1000, 2000, 3000, 5000, 8000, 13000, 21000, 34000, 55000, 60000]
      @reconnectInterval  = null
      @timeoutInterval    = 10000

      @onconnecting = (event) ->
      @onopen       = (event) ->
      @onclose      = (event) ->
      @onmessage    = (event) ->
      @onerror      = (event) ->

      @_connectionTimeout   = null
      @_reconnectionTimeout = null


      @_states =
        connecting:
          name: 'CONNECTING'
          enter: =>
            @readyState = WebSocket.CONNECTING
            @onconnecting({})

            @_connectionTimeout = wait @timeoutInterval, =>
              debug "connection-timeout #{@url}"
              if @ws
                @ws.close()
                @_changeToClosedOrReconnecting({ message: 'connection timeout' })

            @_connect()

          leave: (event) =>
            clearTimeout(@_connectionTimeout)
            @_connectionTimeout = null

          connect: =>

          disconnect: (event) =>
            @ws.close()

          error: (event) =>
            if @ws
              @ws.close()
              @_changeToClosedOrReconnecting({ message: event?.message || 'connection failed' })


        open:
          name: 'OPEN'
          enter: (event) =>
            @readyState = WebSocket.OPEN
            @reconnectInterval = null  # reset intervals after a successful connection
            @onopen event

          leave: (event) =>

          connect: =>

          disconnect: (event) =>
            @ws.close()

          error: (event) =>


        closed:
          name: 'CLOSED'
          enter: (event) =>
            @ws = null
            @readyState = WebSocket.CLOSED
            event = { message: event.message, previousReadyState: @readyState }
            @onclose event

          leave: (event) =>

          connect: =>
            @_changeState @_states.connecting

          disconnect: (event) =>

          error: (event) =>


        reconnecting:
          name: 'RECONNECTING'
          enter: (event) =>
            @ws = null

            event = { message: event.message, previousReadyState: @readyState }
            @readyState = WebSocket.CONNECTING

            @onclose event

            # back-off according to the specified intervals
            if @reconnectInterval
              for interval in @reconnectIntervals
                if interval > @reconnectInterval
                  @reconnectInterval = interval
                  break
            else
              @reconnectInterval = @reconnectIntervals[0]

            debug "reconnecting in #{Math.round(@reconnectInterval/100)/10} sec"
            @_reconnectionTimeout = wait @reconnectInterval, =>
              @_changeState @_states.connecting

          leave: (event) =>
            clearTimeout(@_reconnectionTimeout)
            @_reconnectionTimeout = null

          connect: =>
            @_changeState @_states.connecting

          disconnect: (event) =>
            @_changeToClosedOrReconnecting(event)

          error: (event) =>


      @_state = @_states.closed
      @ws = null
      @readyState = WebSocket.CLOSED


    _changeState: (newState, event) ->
      oldState = @_state
      debug "state: #{oldState.name} => #{newState.name}"

      return if newState is oldState

      @_state.leave(event)
      @_state = newState
      @_state.enter(event)

    _changeToClosedOrReconnecting: (event) ->
      if @_connectionDesired
        @_changeState @_states.reconnecting, event
      else
        @_changeState @_states.closed, event

    _connect: ->
      thisWS = @ws = new WebSocket(@url, @protocols)

      @ws.onopen = (event) =>
        unless @ws is thisWS
          debug "onopen(stale) #{@url}"
          thisWS.close()
          return

        debug "onopen #{@url}"
        @_changeState @_states.open

      @ws.onclose = (event) =>
        unless @ws is thisWS
          debug "onclose(stale) #{@url}"
          return

        debug "onclose #{@url}"
        @_changeToClosedOrReconnecting(event)

      @ws.onmessage = (event) =>
        unless @ws is thisWS
          debug "onmessage(stale) #{@url} - #{event.data}"
          thisWS.close()
          return

        debug "onmessage #{@url} - #{event.data}"
        @onmessage event

      @ws.onerror = (event) =>
        unless @ws is thisWS
          debug "onerror(stale) #{@url} - #{event.message}"
          return

        debug "onerror #{@url} - #{event.message}"
        @onerror event
        @_state.error event


    open: ->
      @_connectionDesired = yes
      process.nextTick =>
        @_state.connect() if @_connectionDesired


    close: ->
      @_connectionDesired = no
      @_state.disconnect(message: 'closing')


    reconnect: ->
      @_connectionDesired = yes
      @_state.disconnect(message: 'reconnecting')


    send: (data) ->
      unless @readyState is WebSocket.OPEN
        throw "INVALID_STATE_ERR : ReWebSocket not connected"

      debug "send #{@url} - #{data}"
      @ws.send data
