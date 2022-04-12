import Lean
open Lean Server

elab "register_rpc" decl:ident : command => registerRpcProcedure decl.getId

open Lean.Widget RequestM Lean.Server Lean in
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

-- [todo] copied from mathlib, I think this should be in core.
open Elab.Command MonadRecDepth in
def liftCommandElabM (k : CommandElabM α) : CoreM α := do
  let (a, commandState) ←
    k.run {
      fileName := (← getEnv).mainModule.toString,
      fileMap := default,
      tacticCache? := none,
    } |>.run {
      env := ← getEnv,
      maxRecDepth := ← getMaxRecDepth,
      scopes := [{ header := "", opts := ← getOptions }]
    }
  modify fun coreState => { coreState with
    traceState.traces := coreState.traceState.traces ++ commandState.traceState.traces
    env := commandState.env
  }
  if let some err := commandState.messages.msgs.toArray.find?
      (·.severity matches MessageSeverity.error) then
    throwError err.data
  pure a

def rpcAttributeImpl : AttributeImpl where
  name := `rpc
  descr := "Marks a function as a Lean server RPC method."
  applicationTime := AttributeApplicationTime.afterCompilation
  add decl stx kind := do
    liftCommandElabM <| Elab.Command.elabCommand <| ← `(register_rpc $(mkIdent decl))
    return ()

initialize registerBuiltinAttribute rpcAttributeImpl
