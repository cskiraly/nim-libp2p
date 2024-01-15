# Nim-LibP2P
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [].}

import chronos, chronicles, stew/results
import ../../stream/connection

type
  RpcMessageQueue* = ref object
    priorityQueue: AsyncQueue[seq[byte]]
    nonPriorityQueue: AsyncQueue[seq[byte]]

proc addPriorityMessage*(aq: RpcMessageQueue; msg: seq[byte]) {.async.} =
  await aq.priorityQueue.put(msg)

proc addNonPriorityMessage*(aq: RpcMessageQueue; msg: seq[byte]) {.async.} =
  await aq.nonPriorityQueue.put(msg)

proc new*(T: typedesc[RpcMessageQueue]): T =
  return T(
    priorityQueue: newAsyncQueue[seq[byte]](),
    nonPriorityQueue: newAsyncQueue[seq[byte]]()
  )

proc getPriorityMessage*(rpcMessageQueue: RpcMessageQueue): Future[Opt[seq[byte]]] {.async.} =
  return
    if not rpcMessageQueue.priorityQueue.empty():
      Opt.some(rpcMessageQueue.priorityQueue.getNoWait())
    else:
      Opt.none(seq[byte])

proc getNonPriorityMessage*(rpcMessageQueue: RpcMessageQueue): Future[Opt[seq[byte]]] {.async.} =
  return
    if not rpcMessageQueue.nonPriorityQueue.empty():
      Opt.some(rpcMessageQueue.nonPriorityQueue.getNoWait())
    else:
      Opt.none(seq[byte])
