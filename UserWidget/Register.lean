import Mathlib.Tactic.Ext
open Lean

macro "register_rpc" decl:ident : command => `(#eval Lean.Server.registerRpcProcedure $(quote decl.getId) _ _ $decl )

def rpcAttributeImpl : AttributeImpl where
  name := `rpc
  descr := "Marks a function as a Lean server RPC method."
  applicationTime := AttributeApplicationTime.afterCompilation
  add decl stx kind := do
    Mathlib.Tactic.Ext.liftCommandElabM <| Elab.Command.elabCommand <| ← `(register_rpc $(mkIdent decl))
    return ()

initialize registerBuiltinAttribute rpcAttributeImpl
