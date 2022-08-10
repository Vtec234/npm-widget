import UserWidget.ToHtml.Widget
import UserWidget.Json
import Std

open Std

open Lean.Widget in
@[widget]
def ppp : UserWidgetDefinition where
  name := "This is a plot"
  javascript := include_str ".." / ".." / "widget" / "dist" / "plot.js"

def fn (x : Float): Float :=
  2 + x - x * x + 2 * (x * x * x)

def data := List.range 10 |> List.map Float.ofNat |>.toArray
      |> Array.map (fun x => x / 10)
      |> Array.map (fun x => json% {x: $(x), y: $(fn x)})
      |> Lean.Json.arr

def props := json% {data: $(data)}

#eval props

#widget ppp props