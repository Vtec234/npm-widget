import UserWidget.ToHtml.Widget
import UserWidget.Json
import Std

open Std

open Lean.Widget in
@[widget]
def plotter : UserWidgetDefinition where
  name := "Function plot"
  javascript := include_str ".." / ".." / "widget" / "dist" / "plot.js"

def fn (t : Float) (x : Float): Float :=
   1.2 * x - 4 * x * x+ 1 * (x * x * x) + 0.1 * (x * 45 + (t / 100) * 2 * 3.14 ).sin


def N := 100
def data (fn : Float → Float) := List.range (N + 1) |> List.map Float.ofNat |>.toArray
      |> Array.map (fun x => x / N.toFloat)
      |> Array.map (fun x => json% {x: $(x), y: $(fn x)})
      |> Lean.Json.arr

def props := json% {
  yDomain : [-2, 1],
  frame_milliseconds: 10,
  useTimer : true,
  data: $(
    List.range 100
    |> List.map (fun t => data (fn <| t.toFloat))
    |> List.toArray
    |> Lean.Json.arr)}
def props2 := json% {data: $(data (fn 1 ∘ fn 2))}
#eval props

-- tip: try pinning the widget in the infoview
-- and then editing the 'fn' above to watch the
-- plot animate
#widget plotter props


-- kjhk


#widget plotter props2