import Lean.Meta
import Lean.Elab.Term

open Lean Elab Term System

syntax (name := includeDataFile) "include_data_file" str : term

@[termElab includeDataFile] def includeDataFileImp : TermElab := fun stx expectedType? => do
  let str := stx[1].isStrLit?.get!
  let s ← IO.FS.readFile <| FilePath.mk str
  return mkStrLit s

def widgetJs : String := include_data_file "./widget/dist/index.js"