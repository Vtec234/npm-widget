import Lean
import UserWidget.RpcHelpers

open Lean Server

namespace Lean.Widget

namespace StaticJS

private unsafe def mkAttributeUnsafe : IO (KeyedDeclsAttribute String) :=
    KeyedDeclsAttribute.init {
      name := `staticJS
      descr := "Mark a string as static JS that can be loaded by a widget handler."
      valueTypeName := `String
    } `Lean.Widget.widgetCodeAttribute

@[implementedBy mkAttributeUnsafe]
constant mkAttribute : IO (KeyedDeclsAttribute String)

initialize Attribute : KeyedDeclsAttribute String ← mkAttribute

/-!
# Usage of `StaticJS.Attribute`

The below code registers some static code called `widget1`.
Note that the name in the attribute is what matters.

```lean
@[staticJS widget1]
def widget1Code := `
  import * as React from "react";
  export default function (props) {
    return React.createElement("p", {}, "hello")
  }`
```

[todo] maybe make the attribute just use the decl name?

-/

/-- Arguments for Widget_getCode RPC. -/
structure Args where
  widgetId : Name
  pos : Lean.Lsp.TextDocumentPositionParams
  deriving ToJson, FromJson




end StaticJS

open StaticJS in
/-- Given a sourcefile position and a widgetId,
returns the javascript sourcecode for the widget at this point.

The sourcecode must be a valid javascript module, whose default export
is a React component whose props are an RPC encoding.

This static JS must include `import * as React from "react"` in the imports and may not use JSX.

[todo]: this needs to be cached on the client infoview and should not change/depend on position.
In the case of bundled libraries (eg plotly), these code files can be many megabytes.
The position is only used to get an environment snapshot after the code has been defined.
However the cache _should_ be invalidated if dependencies are rebuilt.
-/
@[rpc]
def getStaticJS (args : Args) : RequestM (RequestTask String) :=
  requestAt args.pos fun snap => do
      let env := snap.cmdState.env
      let js := Attribute.getEntries env args.widgetId
      if let some j := js.head? then
        return j.value
      else
        throw  (RequestError.mk JsonRpc.ErrorCode.invalidParams s!"No registered widget with name {args.widgetId}")

open Lean.Widget RequestM Lean.Server Lean

structure GetWidgetResponse where
  id : Name
  props : Json
  deriving ToJson, FromJson


def isWidget (e : Lean.Elab.CustomInfo) : Option GetWidgetResponse := Except.toOption (do
  let v ← e.json.getObjVal? "kind"
  let s ← v.getStr?
  if (s != "widget") then
    throw "not a widget"
  let id : Name ← fromJson? <|← e.json.getObjVal? "id"
  let props ← e.json.getObjVal? "props"
  pure {id := id, props := props}
)
open Lean Elab in
/--
  Try to retrieve `CustomInfo`
-/
partial def InfoTree.customInfoAt? (text : FileMap) (t : InfoTree) (hoverPos : String.Pos) : List GetWidgetResponse := Id.run do
  let cis := t.deepestNodes fun
    | ctx, i@(Info.ofCustomInfo ci), cs => OptionM.run do
      if let (some pos, some tailPos) := (i.pos?, i.tailPos?) then
        let trailSize := i.stx.getTrailingSize
        -- show info at EOF even if strictly outside token + trail
        let atEOF := tailPos.byteIdx + trailSize == text.source.endPos.byteIdx
        guard <| pos ≤ hoverPos ∧ (hoverPos.byteIdx < tailPos.byteIdx + trailSize || atEOF)
        return ci
      else
        failure
    | _, _, _ => none
  return cis.filterMap isWidget

@[rpc]
def getWidget (args : Lean.Lsp.TextDocumentPositionParams) : RequestM (RequestTask (Option GetWidgetResponse)) := do
  let doc ← readDoc
  let pos := doc.meta.text.lspPosToUtf8Pos args.position
  requestAt args fun snap => do
      let widgets := InfoTree.customInfoAt? doc.meta.text snap.infoTree pos
      if let some x := widgets.getLast? then
        return x
      else
        return none

end Lean.Widget








