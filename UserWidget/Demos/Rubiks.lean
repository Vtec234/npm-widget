import Lean
import UserWidget.Json
import UserWidget.WidgetCode
import UserWidget.Util
open Lean Elab Command


@[staticJS]
def rubiks : String := include_str "../../widget/dist/rubiks.js"

#widget rubiks {seq : ["U", "L", "R", "L⁻¹", "F"] }