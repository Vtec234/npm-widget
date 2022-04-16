import Lean.Server.Requests
import Lean.Server.Rpc
open Lean Server

open RequestM in
/-- Helper for running an Rpc request at a particular snapshot. -/
def requestAt
  (lspPos : Lean.Lsp.TextDocumentPositionParams)
  (f : Snapshots.Snapshot → RequestM α): RequestM (RequestTask α) := do
  let doc ← readDoc
  let pos := doc.meta.text.lspPosToUtf8Pos lspPos.position
  withWaitFindSnap
    doc
    (fun s => s.endPos >= pos)
    (notFoundX := throw $ RequestError.mk JsonRpc.ErrorCode.invalidRequest s!"no snapshot found at {lspPos}")
    f

def rpcAttributeImpl : AttributeImpl where
  name := `rpc
  descr := "Marks a function as a Lean server RPC method."
  applicationTime := AttributeApplicationTime.afterCompilation
  add decl stx kind := do
    registerRpcProcedure decl
    return ()

initialize registerBuiltinAttribute rpcAttributeImpl