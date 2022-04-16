import UserWidget.RpcHelpers

namespace Lean.Widget

open Server

structure StaticJS where
  javascript : String
  hash : UInt64 := hash javascript
  deriving Inhabited, ToJson, FromJson

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

protected def find? (env : Environment) (id : Name) : Option StaticJS :=
  extension.find? env id

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

/-- Arguments for Widget_getCode RPC. -/
structure Args where
  widgetId : Name
  pos : Lean.Lsp.TextDocumentPositionParams
  deriving ToJson, FromJson

end StaticJS


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
def getStaticJS (args : StaticJS.Args) : RequestM (RequestTask StaticJS) :=
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
  Try to retrieve `CustomInfo`
-/
partial def InfoTree.customInfoAt? (text : FileMap) (t : InfoTree) (hoverPos : String.Pos) : List CustomInfo :=
  t.deepestNodes fun
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


@[rpc]
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








