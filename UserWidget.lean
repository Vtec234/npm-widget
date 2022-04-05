import Lean.Meta
import Lean.Server.Rpc
import Lean.Elab.Term
import UserWidget.Register

open Lean Elab Term System Server

syntax (name := includeDataFile) "include_data_file" str : term

@[termElab includeDataFile] def includeDataFileImp : TermElab := fun stx expectedType? => do
  let str := stx[1].isStrLit?.get!
  let s ← IO.FS.readFile <| FilePath.mk str
  return mkStrLit s

def widgetJs : String := include_data_file "./widget/dist/index.js"

@[rpc]
def Widget_getCodeAtPoint (pos : Lean.Lsp.TextDocumentPositionParams) := RequestM.asTask <| pure <| widgetJs
