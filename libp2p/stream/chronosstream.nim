## Nim-LibP2P
## Copyright (c) 2019 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

import chronos, chronicles
import lpstream, ../utility

logScope:
  topic = "ChronosStream"

type ChronosStream* = ref object of LPStream
    client: StreamTransport

proc newChronosStream*(client: StreamTransport): ChronosStream =
  new result
  result.client = client
  result.closeEvent = newAsyncEvent()

template withExceptions(body: untyped) =
  try:
    body
  except TransportIncompleteError:
    # for all intents and purposes this is an EOF
    raise newLPStreamEOFError()
  except TransportLimitError:
    raise newLPStreamLimitError()
  except TransportUseClosedError:
    raise newLPStreamEOFError()
  except TransportError:
    # TODO https://github.com/status-im/nim-chronos/pull/99
    raise newLPStreamEOFError()
    # raise (ref LPStreamError)(msg: exc.msg, parent: exc)

method readExactly*(s: ChronosStream,
                    pbytes: pointer,
                    nbytes: int): Future[void] {.async.} =
  if s.atEof:
    raise newLPStreamEOFError()

  withExceptions:
    await s.client.readExactly(pbytes, nbytes)

method readOnce*(s: ChronosStream, pbytes: pointer, nbytes: int): Future[int] {.async.} =
  if s.atEof:
    raise newLPStreamEOFError()

  withExceptions:
    result = await s.client.readOnce(pbytes, nbytes)

method write*(s: ChronosStream, msg: seq[byte]) {.async.} =
  if s.closed:
    raise newLPStreamClosedError()

  if msg.len == 0:
    return

  withExceptions:
    var writen = 0
    while not s.client.closed and writen < msg.len:
      writen += await s.client.write(msg[writen..<msg.len])

    if writen < msg.len:
      raise (ref LPStreamClosedError)(msg: "Write couldn't finish writing")

method closed*(s: ChronosStream): bool {.inline.} =
  result = s.client.closed

method atEof*(s: ChronosStream): bool {.inline.} =
  s.client.atEof()

method close*(s: ChronosStream) {.async.} =
  try:
    if not s.isClosed:
      s.isClosed = true

      trace "shutting down chronos stream", address = $s.client.remoteAddress()
      if not s.client.closed():
        await s.client.closeWait()

      s.closeEvent.fire()
  except CatchableError as exc:
    trace "error closing chronosstream", exc = exc.msg
