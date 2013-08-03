discard """
  file: "tasynciterraw.nim"
  cmd: "nimrod cc --hints:on $# $#"
  output: "10000"
"""
# This is a control test in case the macro expansion starts failing. It's the
# raw code after macro expansion in tasyncitermacro.nim.

import asyncio, sockets, strutils

var globalCount = 0

type
  PsendCount3ArgObject = ref object of TObject
    dummy1: PAsyncSocket
    dummy2: int

proc sendCount3(client: PAsyncSocket; count: int): PsendCount3ArgObject = 
  new(result)
  result.dummy1 = client
  result.dummy2 = count

iterator sendCount3(x: PRequest): PRequest {.closure.} = 
  let passedInParams = PsendCount3ArgObject(x.param)
  let client = passedInParams.dummy1
  let count = passedInParams.dummy2
  var sendReq = PRequest(socket: client, kind: reqWrite, 
                         toWrite: $ count & "\x0D\x0A")
  yield sendReq
  if sendReq.hasException: raise sendReq.exc


type 
  PsendCount2ArgObject = ref object of TObject
    dummy1: PAsyncSocket
    dummy2: int

proc sendCount2(client: PAsyncSocket; count: int): PsendCount2ArgObject = 
  new(result)
  result.dummy1 = client
  result.dummy2 = count

iterator sendCount2(x: PRequest): PRequest {.closure.} = 
  let passedInParams = PsendCount2ArgObject(x.param)
  let client = passedInParams.dummy1
  let count = passedInParams.dummy2
  var argsToPass = sendCount3(client, count)
  yield PRequest(socket: nil, kind: reqAwait, worker: sendCount3, 
                 param: argsToPass)


type 
  PsendCountArgObject = ref object of TObject
    dummy1: PAsyncSocket
    dummy2: int

proc sendCount(client: PAsyncSocket; count: int): PsendCountArgObject = 
  new(result)
  result.dummy1 = client
  result.dummy2 = count

iterator sendCount(x: PRequest): PRequest {.closure.} = 
  let passedInParams = PsendCountArgObject(x.param)
  let client = passedInParams.dummy1
  let count = passedInParams.dummy2
  var argsToPass = sendCount2(client, count)
  yield PRequest(socket: nil, kind: reqAwait, worker: sendCount2, 
                 param: argsToPass)


type 
  PprocessRequestArgObject = ref object of TObject
    dummy1: PAsyncSocket
    dummy2: string
    dummy3: bool

proc processRequest(client: PAsyncSocket; paramTest: string; 
                    closeSock: bool = true): PprocessRequestArgObject = 
  new(result)
  result.dummy1 = client
  result.dummy2 = paramTest
  result.dummy3 = closeSock

iterator processRequest(x: PRequest): PRequest {.closure.} = 
  let passedInParams = PprocessRequestArgObject(x.param)
  let client = passedInParams.dummy1
  let paramTest = passedInParams.dummy2
  let closeSock = passedInParams.dummy3
  doAssert paramTest == "foobarbaz"
  assert client != nil
  var count = 0
  while true: 
    var readLineReq = PRequest(socket: client, kind: reqReadLine, line: "")
    yield readLineReq
    if readLineReq.hasException: raise readLineReq.exc
    let line = readLineReq.line
    if line == "end":
      break
    doAssert line.startswith("Message")
    doAssert line == "Message" & $ count
    count.inc
  var argsToPass = sendCount(client, count)
  yield PRequest(socket: nil, kind: reqAwait, worker: sendCount,
                 param: argsToPass)
  doAssert closeSock
  if closeSock:
    client.close()

type 
  PstartServerArgObject = ref object of TObject
    
proc startServer(): PstartServerArgObject = 
  nil

iterator startServer(x: PRequest): PRequest {.closure.} = 
  var sock = AsyncSocket()
  #sock.setReuseAddr()
  sock.bindAddr(TPort(10235))
  sock.listen()
  while true: 
    var acceptReq = PRequest(socket: sock, kind: reqAccept, client: nil, 
                             hasException: false)
    yield acceptReq
    if acceptReq.hasException: raise acceptReq.exc
    let client = acceptReq.client
    assert client != nil
    var argsToPass = processRequest(client, "foobarbaz")
    yield PRequest(socket: nil, kind: reqReg, worker: processRequest, 
                   param: argsToPass)


type 
  PspawnClientArgObject = ref object of TObject
    
proc spawnClient(): PspawnClientArgObject = 
  nil

iterator spawnClient(x: PRequest): PRequest {.closure.} = 
  var client = AsyncSocket()
  var connectReq = PRequest(socket: client, kind: reqConnect, 
                            address: "localhost", port: TPort(10235))
  yield connectReq
  if connectReq.hasException: raise connectReq.exc
  for i in 0 .. 99: 
    var sendReq = PRequest(socket: client, kind: reqWrite, 
                           toWrite: "Message" & $ i & "\x0D\x0A")
    yield sendReq
    if sendReq.hasException: raise sendReq.exc
  
  
  var sendReq1 = PRequest(socket: client, kind: reqWrite, 
                         toWrite: "end\x0D\x0A")
  yield sendReq1
  if sendReq1.hasException: raise sendReq1.exc
  
  var readLineReq = PRequest(socket: client, kind: reqReadLine, line: "")
  yield readLineReq
  if readLineReq.hasException: raise readLineReq.exc
  
  let line = readLineReq.line
  doAssert line == "100"
  globalCount.inc(100)
  client.close()

type 
  PspawnClientsArgObject = ref object of TObject
    
proc spawnClients(): PspawnClientsArgObject = 
  nil

iterator spawnClients(x: PRequest): PRequest {.closure.} = 
  for i in 0 .. 99: 
    var argsToPass = spawnClient()
    yield PRequest(socket: nil, kind: reqReg, worker: spawnClient,
                   param: argsToPass)

var disp = newDispatcher(false)
disp.register(startServer, nil)
disp.register(spawnClients, nil)
while true:
  discard disp.poll()

  if globalCount == 100*100:
    echo(globalCount)
    quit(QuitSuccess)
