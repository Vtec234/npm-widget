import UserWidget.WidgetCode
import UserWidget.Util
import UserWidget.ToHtml.Html

@[staticJS]
def staticHtmlWidget : String := include_str "../../widget/dist/staticHtml.js"

syntax (name := html) "html!" term : tactic
open Lean Elab Tactic Meta Widget in
unsafe def htmlTacUnsafe : Tactic := fun stx => do
  let id := `staticHtmlWidget
  let htmlT := mkConst ``Html
  let htExpr ← elabTerm stx[1] htmlT
  let decl := Declaration.defnDecl {
    name        := `_aux_html
    levelParams := []
    type        := htmlT
    value       := htExpr
    hints       := ReducibilityHints.opaque
    safety      := DefinitionSafety.safe
  }
  let env ← getEnv
  try
    addAndCompile decl
    let ht ← evalConstCheck Html ``Html `_aux_html
    let props := Json.mkObj [("html", toJson ht)]
    Lean.Widget.saveWidget id props stx
  finally
    -- Reset the environment to one without the auxiliary config constant
    setEnv env

open Lean Elab Tactic Meta Widget in
@[implementedBy htmlTacUnsafe]
constant htmlTac : Tactic := fun stx => return ()

-- NB: two attributes on one def doesn't seem to work
@[tactic html]
def htmlTac' := htmlTac