import Lean
import UserWidget.WidgetCode
import Mathlib.Util.IncludeStr
open Lean Server Elab

#check pushInfoTree

def codefn (s : String) := s!"
  import * as React from 'react';
  export default function (props) \{
    return React.createElement('p', \{}, `{s} ::::::::::: $\{props.pos}`)
  }"

@[staticJS widget1]
def widget1 : String := codefn "widget1"

@[staticJS widget2]
def widgetJs : String := include_str "../widget/dist/index.js"

@[staticJS widget3]
def widget2 : String := codefn "widget3"

open Tactic

#check withInfoContext
#check saveTacticInfoForToken
#check String.Pos

syntax (name := widget) "widget!" : tactic
@[tactic widget]
def widgetTac : Tactic := fun stx => do
  if let some pos := stx.getPos? then
    let id := `widget1
    let props := Json.mkObj [("pos", pos.byteIdx)]
    let j := Json.mkObj [
      ("kind", "widget"),
      ("id", toJson id),
      ("props", props)
    ]
    CustomInfo.mk stx j
    |> Info.ofCustomInfo
    |> pushInfoLeaf

theorem asdf : True := by
  dbg_trace "hello"
  widget!
  trivial

#eval "hello"

def foo := 3

#eval foo

