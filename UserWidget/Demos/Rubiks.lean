import Lean
import UserWidget.Json
import UserWidget.Util
open Lean Elab Command

@[widgetSource]
def rubiks : String := include_str "../../widget/dist/rubiks.js"

#widget rubiks (json% {seq : ["U", "L", "R", "L⁻¹", "R"] })