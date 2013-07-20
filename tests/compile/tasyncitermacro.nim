import sockets, asyncio, strutils
proc processRequest(client: PAsyncSocket, test: string) {.async.} =
  assert test == "ahha"
  assert client != nil
  echo(test)
  client.close()

proc processServer() {.async.} =
  var sock = AsyncSocket()
  
  # blocks:
  sock.bindAddr(TPort(6667))
  sock.listen()
  
  # Accept loop
  while true:
    let client: PAsyncSocket = await(accept(sock))
    assert client != nil
    await processRequest(client, "ahha")

var disp = newDispatcher(false)
disp.register(processServer, nil)
while true:
  discard disp.poll()
