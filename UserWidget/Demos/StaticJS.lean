import UserWidget.WidgetCode
import UserWidget.Util

def codefn (s : String) := s!"
  import * as React from 'react';
  export default function (props) \{
    return React.createElement('p', \{}, `{s} asdf $\{props.pos}`)
  }"

@[staticJS]
def widget1 : String := codefn "widget1"

@[staticJS]
def widgetJs : String := include_str "../../widget/dist/index.js"

@[staticJS widget3]
def widget2 : String := codefn "widget3"

syntax (name := widget) "widget!" : tactic
open Lean Elab Tactic in
@[tactic widget]
def widgetTac : Tactic := fun stx => do
  if let some pos := stx.getPos? then
    let id := `widget1
    let props := Json.mkObj [("pos", pos.byteIdx)]
    Lean.Widget.saveWidget id props stx

theorem asdf : True := by
  widget!
  trivial