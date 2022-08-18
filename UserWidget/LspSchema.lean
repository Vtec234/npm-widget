import UserWidget.Schema
open Lean Json
namespace Lean.Lsp


namespace Schema

structure _Property (JType : Type) where
  name: String
  type: JType
  documentation?: Option String
  optional?: Option Bool
  deriving FromJson, Repr

inductive JType
  | reference (name : String)
  | union (items: Array JType)
  | null
  | array (element: JType)
  | string
  | stringLiteral (value : String)
  | boolean
  | number
  | decimal
  | uinteger
  | integer
  | DocumentUri
  | objectLiteral (properties : Array (_Property JType))
  | or (items: Array JType)
  | and (items: Array JType)
  | tuple (items: Array JType)
  | map (key : JType) (value : JType)
  deriving Repr

protected partial def JType.fromJson? (j : Json) : Except String JType := do
    let kind ← Json.getStr? <|← j.getObjVal? "kind"
    match kind with
    | "base" =>
      let name ← Json.getStr? <|← j.getObjVal? "name"
      match name with
      | "string" => return JType.string
      | "number" => return JType.number
      | "null" => return JType.null
      | "boolean" => return JType.boolean
      | "uinteger" => return JType.uinteger
      | "decimal" => return JType.decimal
      | "integer" => return JType.integer
      | "DocumentUri" => return JType.DocumentUri
      | _ => throw s!"Unknown base type name {name}"
    | "literal" =>
      have : FromJson JType := ⟨JType.fromJson?⟩
      let v ← j.getObjVal? "value"
      let v ← v.getObjVal? "properties"
      return JType.objectLiteral <|← fromJson? v
    | "array" =>
      let elt ← j.getObjVal? "element"
      let t ← JType.fromJson? elt
      return JType.array t
    | "reference" =>
      let name ← fromJson? <|← j.getObjVal? "name"
      return JType.reference name
    | "or" =>
      have : FromJson JType := ⟨JType.fromJson?⟩
      let items ← j.getObjVal? "items"
      return JType.or <|← fromJson? items
    | "and" =>
      have : FromJson JType := ⟨JType.fromJson?⟩
      let items ← j.getObjVal? "items"
      return JType.and <|← fromJson? items
    | "tuple" =>
      have : FromJson JType := ⟨JType.fromJson?⟩
      let items ← j.getObjVal? "items"
      return JType.tuple <|← fromJson? items
    | "map" =>
      let k ← j.getObjVal? "key"
      let v ← j.getObjVal? "value"
      return JType.map (← JType.fromJson? k) (← JType.fromJson? v)
    | "stringLiteral" =>
      return JType.stringLiteral (← fromJson? <|← j.getObjVal? "value")
    | x => throw s!"Unknown type {x}"


instance : FromJson JType := ⟨JType.fromJson?⟩
def Property := _Property JType
instance : FromJson Property :=
  show FromJson (_Property JType) by infer_instance
instance: Repr Property where
  reprPrec _ _ := "hello"
structure Reference where
  kind: Singleton "reference"
  name: String
  deriving FromJson, Repr

structure Structure where
  name: String
  properties: Array Property
  ext?: Option (Array Reference)
  mixins?: Option (Array Reference)
  documentation?: Option String := none
  deriving FromJson, Repr

structure Request where
  method: String
  params?: Option JType
  result: JType
  -- registrationOptions
  -- partialResult
  documentation?: Option String := none
  deriving FromJson, Repr

structure Notification where
  method : String
  params?: Option JType
  -- registrationOptions
  documentation?: Option String := none
  deriving FromJson, Repr

structure EnumerationValue (V : Type) where
  /-- Pretty name for Javascript-/
  name: String
  /-- Value corresponding to name. -/
  value: V
  documentation?: Option String
  deriving FromJson, Repr

inductive EnumerationType where
  | string | number

@[reducible] def EnumerationType.toType : EnumerationType → Type
  | string => String | number => Int


structure Enumeration where
  name: String
  type: EnumerationType
  documentation?: Option String
  values: Array (EnumerationValue type.toType)



instance : FromJson Enumeration where
  fromJson? j := do
    let name : String ←  fromJson? <|← j.getObjVal? "name"
    let type : JType ← fromJson? <|← j.getObjVal? "type"
    let values ← j.getObjVal? "values"
    let documentation : Option String ← ((j.getObjVal? "documentation" >>= Json.getStr? >>= (pure ∘ some))) <|> (pure none)
    match type with
      | JType.string => return {name, type:= EnumerationType.string,  values := (← fromJson? values), documentation? := documentation}
      | JType.integer
      | JType.uinteger => return {name, type:= EnumerationType.number,  values := (← fromJson? values), documentation? := documentation}
      | _ => throw s!"Unexpected enumeration value type {repr type}"

structure Alias where
  name: String
  type: JType
  deriving FromJson, Repr

structure LspSchema where
  requests: Array Request
  notifications: Array Notification
  structures: Array Structure
  enumerations: Array Enumeration
  aliases : Array Alias
  deriving FromJson

open Lean Elab Command
abbrev  SchemaM := ReaderT LspSchema CommandElabM

private def mkDocComment (s : String) : Syntax :=
  mkNode ``Lean.Parser.Command.docComment #[mkAtom "/--", mkAtom (s ++ "-/")]

open PrettyPrinter Lean.Parser.Command
#check (234 : Int).natAbs
def jsonValues (e : Enumeration) : CommandElabM (Array (TSyntax `term)) := by
  cases e with name type values foo

  induction e.type with
  | number =>
    have vs : Array (EnumerationValue Int) := e.values

    sorry
    -- exact (do
    -- vs.mapM (fun x =>
    --   if x >= 0 then
    --     `(Json.num ($(quote x.value.natAbs) : Int))
    --   else
    --     `(Json.num (-$(quote x.value.natAbs) : Int))
    -- )

  | string => exact (do
    let vs : Array (EnumerationValue String) := e.values
    vs.mapM (fun x => `(Json.str $(quote x.value.natAbs)) )
  )

def Enumeration.generate (e : Enumeration) : SchemaM Unit := do
  let env ← getEnv
  if env.contains e.name then return () else
  let T := mkIdent e.name
  let ctorNames := e.values.map (mkIdent ·.name.decapitalize)
  let ctors ← ctorNames.mapM (fun x => `(Lean.Parser.Command.ctor| | $x:ident))
  let cmd ← `(
    inductive $T where
      $[$ctors:ctor]*
  )
  trace[LspSchema] "Creating enumaration:\n{← liftCoreM $ ppCommand cmd}"
  elabCommand cmd
  let encs ←
    match e with
    | {type := EnumerationType.number, values, ..} =>
      let vs : Array (EnumerationValue Int) := e.values
      vs.mapM fun (e : EnumerationValue Int) => `(Json.num ($(instQuoteInt.quote e.value) : Int))
    | EnumerationType.string => _

  return ()


#eval (h.quote (-4 : Int))


-- def Structure.generate (s : Structure) : SchemaM Name := do
--   let env ← getEnv
--   if env.contains s.name then return s.name else
--   let ext := s.ext?.getD #[]
--   let mixins := s.mixins?.getD #[]

--   let cmd ← `(
--     inductive $(mkIdent )
--   )
--   return _


end Schema
open Schema
-- downloaded from: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#metaModel
def schema :=
  (include_str "lsp.schema.json")
  |> Json.parse
  |>.bind (fromJson? (α := LspSchema))


def generateStructure

def generate (s : LspSchema) (decl : Name) : CommandElabM Unit := do



#eval schema

end Lean.Lsp