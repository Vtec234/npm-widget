import Lean
namespace Lean.Widget

open Server

structure StaticJS where
  javascript : String
  hash : UInt64 := hash javascript
  deriving Inhabited, ToJson, FromJson

open RequestM in
/-- Helper for running an Rpc request at a particular snapshot. -/
def requestAt
  (lspPos : Lean.Lsp.TextDocumentPositionParams)
  (f : Snapshots.Snapshot → RequestM α): RequestM (RequestTask α) := do
  let doc ← readDoc
  let pos := doc.meta.text.lspPosToUtf8Pos lspPos.position
  withWaitFindSnap
    doc
    (fun s => s.endPos >= pos)
    (notFoundX := throw $ RequestError.mk JsonRpc.ErrorCode.invalidRequest s!"no snapshot found at {lspPos}")
    f

namespace StaticJS

initialize extension : MapDeclarationExtension StaticJS ← mkMapDeclarationExtension `staticJS

private unsafe def attributeImplUnsafe : AttributeImpl where
  name := `staticJS
  descr := "Mark a string as static JS that can be loaded by a widget handler."
  applicationTime := AttributeApplicationTime.afterCompilation
  add decl stx kind := do
    let env ← getEnv
    let value ← evalConstCheck String ``String decl
    setEnv <| extension.insert env decl {javascript := value}

@[implementedBy attributeImplUnsafe]
constant attributeImpl : AttributeImpl

/-- Find the static-js for the given widget id. -/
protected def find? (env : Environment) (id : Name) : Option StaticJS :=
  extension.find? env id

/-- Returns true if the environment contains static-js for the given widget id. -/
protected def contains (env : Environment) (id : Name) : Bool :=
  extension.contains env id

/-- Gets the hash of the static javascript string for the given widget id, or returns zero if
there is no static javascript registered. -/
def getHash [MonadEnv m] [Monad m] (id : Name) : m UInt64 := do
  let env ← getEnv
  let some j := StaticJS.find? env id | return 0
  return j.hash

initialize registerBuiltinAttribute attributeImpl


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

end StaticJS

/-- Arguments for getStaticJS RPC. -/
structure GetStaticJSArgs where
  widgetId : Name
  pos : Lean.Lsp.TextDocumentPositionParams
  deriving ToJson, FromJson

/-- Given a sourcefile position and a widgetId,
returns the javascript sourcecode for the widget at this point.

The sourcecode must be a valid javascript module, whose default export
is a React component whose props are an RPC encoding.

This static JS must include `import * as React from "react"` in the imports and may not use JSX.

Note that javascript strings can be many megabytes long due to bundled libraries.
Because of this, it is important that getStaticJS is not called frequently.
The client should cache static js according to the hash of the javascript code.
-/
@[serverRpcMethod]
def getStaticJS (args : GetStaticJSArgs) : RequestM (RequestTask StaticJS) :=
  requestAt args.pos fun snap => do
      let env := snap.cmdState.env
      if let some js := StaticJS.find? env args.widgetId then
        return js
      else
        throw  (RequestError.mk JsonRpc.ErrorCode.invalidParams s!"No registered widget with name {args.widgetId}")


open Lean.Widget RequestM Lean.Server Lean

structure GetWidgetResponse where
  id : Name
  hash : UInt64
  props : Json
  deriving ToJson, FromJson


def isWidget (e : Lean.Elab.CustomInfo) : Option GetWidgetResponse :=
  fromJson? e.json
  |> Except.toOption

open Lean Elab in
/--
  Try to retrieve the `CustomInfo` at a particular position.
-/
partial def InfoTree.customInfoAt? (text : FileMap) (t : InfoTree) (hoverPos : String.Pos) : List CustomInfo :=
  t.deepestNodes fun
    | ctx, i@(Info.ofCustomInfo ci), cs => do
      if let (some pos, some tailPos) := (i.pos?, i.tailPos?) then
        let trailSize := i.stx.getTrailingSize
        -- show info at EOF even if strictly outside token + trail
        let atEOF := tailPos.byteIdx + trailSize == text.source.endPos.byteIdx
        guard <| pos ≤ hoverPos ∧ (hoverPos.byteIdx < tailPos.byteIdx + trailSize || atEOF)
        return ci
      else
        failure
    | _, _, _ => none


/-- Get the widget id and props at a particular position if it exists. -/
@[serverRpcMethod]
def getWidget (args : Lean.Lsp.TextDocumentPositionParams) : RequestM (RequestTask (Option GetWidgetResponse)) := do
  let doc ← readDoc
  let pos := doc.meta.text.lspPosToUtf8Pos args.position
  requestAt args fun snap => do
      let cis := InfoTree.customInfoAt? doc.meta.text snap.infoTree pos
      let widgets := cis.filterMap isWidget
      if let some x := widgets.getLast? then
        return x
      else
        return none
        -- throw (RequestError.mk JsonRpc.ErrorCode.invalidParams s!"No registered widget at {args}.")

open Elab in
/-- Save a widget to the infotree. -/
def saveWidget [Monad m] [MonadEnv m] [MonadInfoTree m] (id : Name) (props : Json) (stx : Syntax):  m Unit := do
  let r : GetWidgetResponse := {
    id := id,
    hash := ← Lean.Widget.StaticJS.getHash id,
    props := props
  }
  toJson r
  |> CustomInfo.mk stx
  |> Info.ofCustomInfo
  |> pushInfoLeaf


end Lean.Widget








