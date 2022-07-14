import UserWidget.Util
import UserWidget.ToHtml.Widget


def codefn (s : String) := s!"
  import * as React from 'react';
  export default function (props) \{
    return React.createElement('p', \{}, `This is {s} with props $\{JSON.stringify(props)}`)
  }"

open Lean.Widget in
@[widget]
def widget1 : UserWidgetDefinition where
  name := "Hello widget1"
  javascript := codefn "widget1"

syntax (name := widget) "widget!" ident : tactic
open Lean Elab Tactic in
@[tactic widget]
def widgetTac : Tactic
  | stx@`(tactic| widget! $n) => do
    if let some pos := stx.getPos? then
      let id := n.getId
      if ¬ Lean.Widget.userWidgetRegistry.contains (← getEnv) id then 
        throwError "No widget present named '{id}'"
      let props := Json.mkObj [("pos", pos.byteIdx)]
      Lean.Widget.saveWidgetInfo id props stx
  | _ => throwUnsupportedSyntax

theorem asdf : True := by
  widget! widget1
  trivial

open scoped Lean.Widget.Jsx in
theorem ghjk : True := by
  html! <b>What, HTML in Lean?! </b>
  html! <i>And another!</i>
  trivial

