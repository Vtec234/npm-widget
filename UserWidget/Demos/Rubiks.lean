import Lean
import UserWidget.Json
import UserWidget.Util

open Lean.Widget

@[widget]
def rubiks : UserWidgetDefinition where
  name := "Rubik's cube"
  javascript := include_str "../../widget/dist/rubiks.js"

#widget rubiks (json% {seq : ["U", "L", "R", "L⁻¹", "R"] })
