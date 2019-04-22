use "buffered"
use "net"
use "debug"

class _ClientConnHandler is TCPConnectionNotify
  """
  This is the network notification handler for the client. It passes
  received data to the `HTTPParser` to assemble response `Payload` objects.
  """
  let _session: _ClientConnection
  let _buffer: Reader = Reader
  let _parser: HTTPParser
  var _delivered: Bool = false

  new iso create(client: _ClientConnection) =>
    """
    The response builder needs to know which Session to forward
    parsed information to.
    """
    Debug.out("  _CliConHand Create")
    _session = client
    _parser = HTTPParser.response(_session)

  fun ref connected(conn: TCPConnection ref) =>
    """
    Tell the client we have connected.
    """
    Debug.out("  _CliConHand conn")
    _session._connected(conn)

  fun ref connect_failed(conn: TCPConnection ref) =>
    """
    The connection could not be established. Tell the client not to proceed.
    """
    Debug.out("  _CliConHand conn fail")
    _session._connect_failed(conn)

  fun ref auth_failed(conn: TCPConnection ref) =>
    """
    SSL authentication failed. Tell the client not to proceed.
    """
    Debug.out("  _CliConHand auth fail")
    _session._auth_failed(conn)

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    times: USize): Bool
  =>
   """
   Pass a received chunk of data to the `HTTPParser`.
   """
    Debug.out("  _CliConHand received")
   // TODO: inactivity timer
    _buffer.append(consume data)

    // Let the parser take a look at what has been received.
    match _parser.parse(_buffer)
    // Any syntax errors will terminate the connection.
    | ParseError => conn.close()
    end
    true

  fun ref closed(conn: TCPConnection ref) =>
    """
    The connection has closed, possibly prematurely.
    """
    Debug.out("  _CliConHand closed")
    let wk = conn.get_so_error()
    // Debug.out("    " + wk._1.string()) //1
    // Debug.out("    " + wk._2.string()) //0
    _parser.closed(_buffer)
    _buffer.clear()
    _session._closed(conn)

  fun ref throttled(conn: TCPConnection ref) =>
    """
    TCP connection wants us to stop sending. We do not do anything with
    this here;  just pass it on to the `HTTPSession`.
    """
    Debug.out("  _CliConHand th")
    _session.throttled()

  fun ref unthrottle(conn: TCPConnection ref) =>
    """
    TCP can accept more data now. We just pass this on to the
    `HTTPSession`
    """
    Debug.out("  _CliConHand unth")
    _session.unthrottled()

