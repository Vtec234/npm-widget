import UserWidget.ToHtml.Widget
import UserWidget.Json
import Std

open Std

open Lean.Widget in
@[widget]
def ppp : UserWidgetDefinition where
  name := "Function plot"
  javascript := include_str ".." / ".." / "widget" / "dist" / "plot.js"

def fn (x : Float): Float :=
   1.2 * x - 4 * x * x + 3 * (x * x * x) + 0.1 * (x * 20).sin

def data := List.range 101 |> List.map Float.ofNat |>.toArray
      |> Array.map (fun x => x / 100)
      |> Array.map (fun x => json% {x: $(x), y: $(fn x)})
      |> Lean.Json.arr

def props := json% {data: $(data)}

#eval props

-- tip: try pinning the widget in the infoview
-- and then editing the 'fn' above to watch the
-- plot animate
#widget ppp props