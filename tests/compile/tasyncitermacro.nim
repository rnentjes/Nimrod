import sockets, asyncio, strutils

proc auth(client: PAsyncSocket) {.async.} =
  await send(client, "Auth\c\L")

proc processRequest(client: PAsyncSocket, test: string, closeSock: bool = true) {.async.} =
  assert test == "ahha"
  assert client != nil
  let line = await(readLine(client))
  echo("Read: ", line)
  
  for i in 0 .. 10:
    await auth(client)
    #await send(client, "Auth\c\L")
  
  await send(client, "Goodbye.\c\L")
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
    
    reg processRequest(client, "ahha")

var disp = newDispatcher(false)
disp.register(processServer, nil)
while true:
  discard disp.poll()
