/- Generate types from a json schema file. -/
import Lean
open Lean Json Std

namespace Std.RBNode

@[specialize] def mapM {α : Type} {β γ : α → Type} {M : Type → Type} [Monad M] (f : (a : α) → β a → M (γ a))
  : RBNode α β → M (RBNode α γ)
  | RBNode.leaf => return RBNode.leaf
  | RBNode.node color lchild key val rchild => return RBNode.node color (← lchild.mapM f) key (← f _ val) (← rchild.mapM f)

variable {α : Type u} {β γ : α → Type v}

@[specialize] def map (f : {a : α} → β a → γ a)
  : RBNode α β → RBNode α γ
  | RBNode.leaf => RBNode.leaf
  | RBNode.node color lchild key val rchild => RBNode.node color (lchild.map f) key (f val) (rchild.map f)

def toArray (n : RBNode α β) : Array (Sigma β) :=
  n.fold (fun acc k v => acc.push ⟨k,v⟩) ∅

instance : EmptyCollection (RBNode α β) := ⟨RBNode.leaf⟩

end Std.RBNode

namespace Lean.Json

def Singleton {α : Type} (a : α) := {b : α // a = b}

instance [ToJson α] : ToJson (Singleton (a : α)) where
  toJson a := toJson a.val

instance [Repr α] : Repr (Singleton (b : α)) where
  reprPrec _ _ := s!"⟨{repr b}, rfl⟩"

instance [FromJson α] [DecidableEq α] [ToString α] : FromJson (Singleton (a : α)) where
  fromJson? j := do
    let b : α ← fromJson? j
    if h : a = b then
      return ⟨_, h⟩
    else
      throw s!"Expected {a} but was {b}."

instance {p : α → Prop} [ToJson α] : ToJson (Subtype p) where
  toJson a := toJson a.val

instance {p : α → Prop} [FromJson α] [ToString α] [DecidablePred p] : FromJson (Subtype p) where
  fromJson? j := do
    let b : α ← fromJson? j
    if h : p b then
      return ⟨b, h⟩
    else
      throw s!"Value {b} violated predicate."

instance [ToJson α] : ToJson (RBMap String α compare) where
  toJson a := a |>.val |> RBNode.map toJson |> Json.obj

open Except in
instance [FromJson α] : FromJson (RBMap String α compare) where
  fromJson? j := do
    let o ← getObj? j
    o.foldM (fun r k v =>
      match fromJson? v with
      | error e => error s!"{k} - {e}"
      | ok x => ok <| r.insert k x
    ) ∅

namespace Schema

structure Property (T: Type) where
  name: String
  description : Option String
  required : Bool
  type: T
  deriving Repr

inductive Schema where
  | null
  | boolean
  | number
  | integer
  | enum (values : Array String)
  | string
  | array (items: Schema)
  | object (properties : Array (Property Schema))
  | ref (id : String)
  | any
  | union (cases : Array Schema)
  deriving Repr

instance : Inhabited Schema := ⟨Schema.any⟩

protected partial def Schema.fromJson? (j : Json) : Except String Schema := do
    if let Except.ok (Json.str r) := j.getObjVal? "$ref" then
      return Schema.ref r
    let type ← j.getObjVal? "type"
    if let (Json.arr _) := type then
      throw s!"unions are not implemented"
    match ← type.getStr? with
    | "null" => return Schema.null
    | "boolean" => return Schema.boolean
    | "number" => return Schema.number
    | "integer" => return Schema.integer
    | "string" => (
        return Schema.enum <|← fromJson? <|← j.getObjVal? "enum"
      ) <|> (
        return Schema.string
      )
    | "array" =>
      return Schema.array <|← Schema.fromJson? <|← j.getObjVal? "items"
    | "object" =>
      let required : Array String ← (fromJson? <|← j.getObjVal? "required") <|> (pure #[])
      let properties ← Json.getObj? <|← j.getObjVal? "properties"
      let properties : Array (Property Schema) ←
        properties.toArray |>.mapM (fun ⟨k, j⟩ => do
          return {
            name := k
            required := required.contains k
            type := ← Schema.fromJson? j
            description := Except.toOption <| Json.getStr? <|← j.getObjVal? "description"
            }
        )
      return Schema.object <| properties
    | x => throw s!"Unknown type {x}"

instance : FromJson Schema := ⟨Schema.fromJson?⟩

structure Class where
  id: String
  type: Schema
  description: Option String
  deriving Repr, Inhabited

protected def Class.fromJson? (id: String) (j : Json) : Except String Class := do return {
    id := id
    description := Except.toOption <| Json.getStr? <|← j.getObjVal? "description"
    type := ← fromJson? j
  }


structure File where
  defs: Array Class
  root: Class
  deriving Repr, Inhabited

instance : FromJson File where
  fromJson? j := do
    let defs ← (Json.getObj? <|← j.getObjVal? "$defs") <|> (pure ∅)
    let defs ← defs.toArray.mapM (fun ⟨id, j⟩ => Class.fromJson? id j)
    let id ← Json.getStr? <|← j.getObjVal? "$id"
    return {
      root := ← Class.fromJson? id j
      defs := defs
    }

end Schema

end Lean.Json

open Lean Json


def schema :=
  (include_str "lsp.schema.json")
  |> Json.parse
  |>.bind (fromJson? (α := Schema.File))

#eval schema