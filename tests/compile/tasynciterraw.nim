import asyncio, sockets

const qwerty = "qwertyuiopasdfghjklzxcvbnm\c\L"

iterator processRequest(x: PRequest): PRequest {.closure.} =
  # Read first message
  let client = x.socket
  var lineReq = PRequest(socket: client, kind: reqReadLine, line: "")
  yield lineReq
  
  if lineReq.line == "HELLO":
    echo "Got first message."
  
  var longString = qwerty
  for i in 0..109000:
    longString.add($i & qwerty)
    
  var writeReq = PRequest(socket: client, kind: reqWrite, toWrite: longString)
  yield writeReq
  
  # Read second message: No need to create another request object:
  yield lineReq
  
  if lineReq.line == "DOM":
    echo("Got second message.")
  
  client.close()


iterator processServer(x: PRequest): PRequest {.closure.} =
  type
    PTest = ref object of TObject
      param: string
    
  let passedInParams = cast[PTest](x.param)
  assert passedInParams.param == "blah"

  var sock = AsyncSocket()
  
  # blocks:
  sock.bindAddr(TPort(6667))
  sock.listen()

  # Accept loop
  while true:
    var acceptReq = PRequest(socket: sock, kind: reqAccept, client: nil)
    echo("About to yield accept")
    yield acceptReq
    echo("after yield")
    if acceptReq.hasException:
      echo("Got exception[EAssertionFailed]: ", acceptReq.exc of EAssertionFailed)
      echo(acceptReq.exc.msg)
      continue
    
    let client = acceptReq.client
    assert client != nil
    yield PRequest(socket: client, kind: reqReg, param: nil, worker: processRequest)
  
when isMainModule:
  let param = "blah"
  type
    PTest = ref object of TObject
      param: type(param)
  var test = PTest(param: param)
  var disp = newDispatcher(false)
  disp.register(processServer, test)
  while true:
    discard disp.poll()

