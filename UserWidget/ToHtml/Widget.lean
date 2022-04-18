import UserWidget.WidgetCode
import UserWidget.Util
import UserWidget.ToHtml.Html

@[staticJS]
def staticHtmlWidget : String := include_str "../../widget/dist/staticHtml.js"

open Lean Elab Widget in
unsafe def evalHtmlUnsafe (stx : Syntax) : TermElabM Html := do
  let htmlT := mkConst ``Html
  let htExpr ← Term.elabTerm stx htmlT
  let htExpr ← Meta.instantiateMVars htExpr
  Term.evalExpr Html ``Html htExpr

open Lean Elab Widget in
@[implementedBy evalHtmlUnsafe]
constant evalHtml : Syntax → TermElabM Html

syntax (name := htmlCmd) "#html " term : command

open Lean Meta Elab Command in
@[commandElab htmlCmd]
def elabHtmlCmd : CommandElab := fun
  | stx@`(#html%$tk $t:term) =>
    runTermElabM none fun _ => do
      let id := `staticHtmlWidget
      let ht ← evalHtml t
      let props := Json.mkObj [("html", toJson ht)]
      Lean.Widget.saveWidget id props stx
  | stx => throwError "Unexpected syntax {stx}."

syntax (name := htmlTac) "html! " term : tactic

open Lean Elab Tactic in
@[tactic htmlTac]
def elabHtmlTac : Tactic
  | stx@`(tactic| html! $t:term) => do
    let id := `staticHtmlWidget
    let ht ← evalHtml t
    let props := Json.mkObj [("html", toJson ht)]
    Lean.Widget.saveWidget id props stx
  | stx => throwError "Unexpected syntax {stx}."