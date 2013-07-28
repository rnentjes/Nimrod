import sockets, asyncio, strutils

proc processRequest(client: PAsyncSocket, test: string, closeSock: bool) {.async.} =
  assert test == "ahha"
  assert client != nil
  echo("Test = ", test)
  let line = await(readLine(client))
  echo("Read: ", line)
  
  await send(client, "Goodbye.\c\L")
  #await send(client, "Goodbye.\c\L")
  #await send(client, "Goodbye.\c\L")
  if closeSock:
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
    await processRequest(client, "ahha", false)
    await processRequest(client, "ahha", true)

var disp = newDispatcher(false)
disp.register(processServer, nil)
while true:
  discard disp.poll()
