import Lean
import UserWidget.Json
import UserWidget.WidgetCode
import UserWidget.Util
open Lean Elab Command

@[staticJS]
def mathjax : String := include_str "../widget/dist/mathjax.js"

syntax (name := texCmd) "#tex " str : command

@[commandElab texCmd] def elabTexCmd : CommandElab := fun
  | stx@`(#tex $text:str) => do
    if let some text := text.isStrLit? then
      Lean.Widget.saveWidget `mathjax (json% {display : true, tex : $(text)}) stx
      return ()
    else
      throwUnsupportedSyntax
  | _ => throwUnsupportedSyntax