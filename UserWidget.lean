import Lean.Meta
import Lean.Server.Rpc
import Lean.Elab.Term

open Lean Elab Term System Server

syntax (name := includeDataFile) "include_data_file" str : term

@[termElab includeDataFile] def includeDataFileImp : TermElab := fun stx expectedType? => do
  let str := stx[1].isStrLit?.get!
  let s ← IO.FS.readFile <| FilePath.mk str
  return mkStrLit s

def widgetJs : String := include_data_file "./widget/dist/index.js"

#eval (do
  registerRpcProcedure
    `Widget_getCodeAtPoint
    Lean.Lsp.TextDocumentPositionParams
    String
    fun pos =>
      RequestM.asTask do
        return widgetJs
  : CoreM Unit)

-- Widget available from here on