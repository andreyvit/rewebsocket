# ReWebSocket: WebSocket with automatic reconnection

ReWebSocket is 99% API-compatible with WebSocket:

    ReWebSocket = require('rewebsocket')(WebSocket);

    ws = new ReWebSocket("ws://127.0.0.1:3000");
    ws.open();  // the only big difference: need to call open explicitly!

    ws.onmessage = function(event) {
      console.log("Received %j", event.data);
    };
    ws.onopen = function(event) {
      console.log("Connected");
    };
    ws.onclose = function(event) {
      if (event.previousReadyState == WebSocket.OPEN)
        console.log("Disconnected");
      else
        console.log("Connection failed.");
    };
    ws.onerror = function(event) {
      // in most cases, you only want to handle this event for logging purposes
      // console.log("Error: %s", event.message);
    };
    ws.onconnecting = function(event) {
      console.log("Connecting...");
    };


## Installation

    npm install rewebsocket

Also works as a client-side module via Browserify.


## API differences from WebSocket

Method differences:

* You need to call `open` explicitly to start connection.
* You can call `open` and `close` multiple times; after you call `open`, ReWebSocket will try to keep the connection open until you call `close`.
* Additional `reconnect` method closes and reopens the connection.

Event differences:

* In `onclose`, `readyState` will be `WebSocket.CONNECTING` if a reconnection attempt is pending, and `WebSocket.CLOSED` after an explicit `close` call.
* In `onclose`, additional `previousReadyState` property is provided. You can use it to distinguish failed connection attempts from aborted connections, as demonstrated by the example above.
* Additional `onconnecting` event is fired before each connection attempt.

Properties:

* `timeoutInterval` — connectiont timeout in milliseconds, defaults to 10000.
* `reconnectIntervals` — array of delays between reconnection attempts, in milliseconds; defaults to [10, 100, 500, 1000, 2000, 3000, 5000, 8000, 13000, 21000, 34000, 55000, 60000]; use this to specify your preferred back-off scheme; after a successful connection, the first value is used again; the last value is the maximum interval.


## Running the example

    node example/example.js

For additional logging, try:

    DEBUG=rewebsocket node example/example.js


## License

© 2012 Andrey Tarantsov <andrey@tarantsov.com>.

Provided under the MIT license.
