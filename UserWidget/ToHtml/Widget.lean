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

open Lean Meta Elab Command in
elab "#html" t:term : command =>
  runTermElabM none fun _ => do
    let id := `staticHtmlWidget
    let ht ← evalHtml t
    let props := Json.mkObj [("html", toJson ht)]
    Lean.Widget.saveWidget id props t

syntax (name := html) "html!" term : tactic

open Lean Elab Tactic in
@[tactic html]
def htmlTac : Tactic
  | `(tactic| html! $t:term) => do
    let id := `staticHtmlWidget
    let ht ← evalHtml t
    let props := Json.mkObj [("html", toJson ht)]
    Lean.Widget.saveWidget id props t
  | stx => throwError "Unexpected syntax {stx}."