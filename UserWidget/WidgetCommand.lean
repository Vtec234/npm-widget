import UserWidget.WidgetProtocol
import UserWidget.Json

namespace Lean.Widget

syntax (name := widgetCmd) "#widget " ident jso : command

open Elab Command in
@[commandElab widgetCmd] def elabWidgetCmd : CommandElab := fun
  | stx@`(#widget $id:ident $props) => do
    let props : Json ← runTermElabM none (fun _ => evalJson props)
    Lean.Widget.saveWidget id.getId props stx
    return ()
  | _ => throwUnsupportedSyntax

end Lean.Widget