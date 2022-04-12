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


#eval "hello"

def foo := 3

#eval foo

