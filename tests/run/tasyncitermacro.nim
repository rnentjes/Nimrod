discard """
  file: "tasyncitermacro.nim"
  cmd: "nimrod cc --hints:on $# $#"
  output: "10000"
"""
import sockets, asyncio, strutils

var globalCount = 0

proc sendCount3(client: PAsyncSocket, count: int) {.async.} =
  await send(client, $count & "\c\L")

proc sendCount2(client: PAsyncSocket, count: int) {.async.} =
  await sendCount3(client, count)

proc sendCount(client: PAsyncSocket, count: int) {.async.} =
  # Testing multiple levels of custom await calls. Shouldn't have much of a
  # performance impact.
  await sendCount2(client, count)

proc processRequest(client: PAsyncSocket, paramTest: string, closeSock: bool = true) {.async.} =
  doAssert paramTest == "foobarbaz"
  assert client != nil
  var count = 0
  while true:
    let line = await(readLine(client))
    if line == "end": break
    doAssert line.startswith("Message")
    doAssert line == "Message" & $count
    count.inc
  
  await sendCount(client, count)
  
  doAssert closeSock # Testing default params here. We won't be changing it.
  if closeSock:
    client.close()

proc startServer() {.async.} =
  var sock = AsyncSocket()
  #sock.setReuseAddr()
  
  # The following may block, but I don't think it does.
  sock.bindAddr(TPort(10235))
  sock.listen()
  
  # Accept loop
  while true:
    let client: PAsyncSocket = await(accept(sock))
    assert client != nil
    
    reg processRequest(client, "foobarbaz")

proc spawnClient() {.async.} =
  var client = AsyncSocket()
  await connect(client, "localhost", TPort(10235))
  
  for i in 0 .. 99:
    await send(client, "Message" & $i & "\c\L")
  await send(client, "end\c\L")
  
  let line = await(readLine(client))
  doAssert line == "100"
  globalCount.inc(100)
  client.close()

proc spawnClients() {.async.} =
  for i in 0 .. 99:
    reg spawnClient()
  
var disp = newDispatcher(false)
disp.register(startServer, nil)
disp.register(spawnClients, nil)
while true:
  discard disp.poll()

  if globalCount == 100*100:
    echo(globalCount)
    quit(QuitSuccess)
