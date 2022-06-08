/-
Copyright (c) 2022 E.W.Ayers. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: E.W.Ayers
-/
import Lean


/- [TODO] THIS WILL BE IN CORE SOON -/

def Except.get! [Inhabited α] [ToString ε] : Except ε α → α
| Except.ok a => a
| Except.error e => panic! (toString e)

namespace Lean

private abbrev N : Nat := SubExpr.maxChildren

namespace SubExpr.Pos

def top : Pos := 1
def isTop (p : Pos) : Bool := p < N
def current (p : Pos) : Nat := if p.isTop then panic! "already at top" else p % N
def pop (p : Pos) : Pos := if p.isTop then panic! "already at top" else (p - p.current) / N
def push (p : Pos) (c : Nat) : Pos := if c >= N then panic! s!"invalid coordinate {c}" else p * N + c

partial def validate (p : Pos) : Except String Unit := do
  if p.isTop then
    if p != 1 then
      throw s!"invalid root value {p}"
    return ()
  if p.current >= N then
    throw s!"invalid coordinate {p.current} >= {N}"
  validate p.pop


variable {α : Type} [Inhabited α]

/-- Fold over the position starting at the root and heading to the leaf-/
def foldl  (f : α → Nat → α) : α → Pos → α :=
  fix2 (fun r a p => if p.isTop then a else f (r a p.pop) p.current)

/-- Fold over the position starting at the root and heading to the leaf-/
def foldr  (f : Nat → α → α) : Pos → α → α :=
  fix2 (fun r p a => if p.isTop then a else r p.pop (f p.current a))

def foldrM [Monad M] (f : Nat → α → M α) : Pos → α → M α :=
  fix2 (fun r p a => if p.isTop then pure a else f p.current a >>= r p.pop)

def depth (p : Pos) :=
  p.foldr (fun _ => Nat.succ) 0
  -- [todo] is logarithm defined somewhere?

/-- Returns true if `pred` is true for each coordinate in `p`.-/
def all (pred : Nat → Bool) (p : Pos) : Bool :=
  OptionT.run (m := Id) (foldrM (fun n a => if pred n then pure a else failure) p ()) |>.isSome

def append : Pos → Pos → Pos := foldl push

/-- Creates a subexpression `Pos` from an array of 'coordinates'.
Each coordinate is a number {0,1,2} expressing which child subexpression should be explored.
The first coordinate in the array corresponds to the root of the expression tree.  -/
def encode (ps : Array Nat) : Pos :=
  ps.foldl push top

/-- Decodes a subexpression `Pos` as a sequence of coordinates. See `Pos.encode` for details.-/
def decode (p : Pos) : Array Nat :=
  foldl Array.push #[] p

end SubExpr.Pos

namespace SubExpr

def mapPos (f : Pos → Pos) : SubExpr → SubExpr
  | ⟨e,p⟩ => ⟨e, f p⟩

variable {M} [Monad M] [MonadLiftT MetaM M] [MonadControlT MetaM M] [MonadError M]

open Lean.PrettyPrinter.Delaborator SubExpr Lean.Meta

/-- Given a constructor index for Expr, runs `g` on the value of that subexpression and replaces it.
If the subexpression is under a binder it will instantiate and abstract the binder body correctly.
Mdata is ignored. An index of 3 is interpreted as the type of the expression. An index of 3 will throw. -/
private def lensCoord (g : Expr → M Expr) : Nat → Expr → M Expr
  | 0, e@(Expr.app f a _)       => return e.updateApp! (← g f) a
  | 1, e@(Expr.app f a _)       => return e.updateApp! f (← g a)
  | 0, e@(Expr.lam _ y b _)     => return e.updateLambdaE! (← g y) b
  | 1, e@(Expr.lam n y b c)     => return e.updateLambdaE! y <|← withLocalDecl n c.binderInfo y fun x => do mkLambdaFVars #[x] (← g (b.instantiateRev #[x]))
  | 0, e@(Expr.forallE _ y b _) => return e.updateForallE! (← g y) b
  | 1, e@(Expr.forallE n y b c) => return e.updateForallE! y <|← withLocalDecl n c.binderInfo y fun x => do mkForallFVars #[x] (← g (b.instantiateRev #[x]))
  | 0, e@(Expr.letE _ y a b _)  => return e.updateLet! (← g y) a b
  | 1, e@(Expr.letE _ y a b _)  => return e.updateLet! y (← g a) b
  | 2, e@(Expr.letE n y a b _)  => return e.updateLet! y a (← withLetDecl n y a fun x => do mkLetFVars #[x] (← g (b.instantiateRev #[x])))
  | 0, e@(Expr.proj _ _ b _)    => pure e.updateProj! <*> g b
  | n, e@(Expr.mdata _ a _)     => pure e.updateMData! <*> lensCoord g n a
  | 3, _                        => throwError "Lensing on types is not supported"
  | c, e                        => throwError "Invalid coordinate {c} for {e}"

private def lensAux (g : Expr → M Expr) : List Nat → Expr → M Expr
  | [], e => g e
  | head::tail, e => lensCoord (lensAux g tail) head e

/-- Run the given `g` function to replace the expression at the subexpression position. If the subexpression is below a binder
the bound variables will be appropriately instantiated with free variables and reabstracted after the replacement.
If the subexpression is invalid or points to a type then this will throw. -/
def lens (g : Expr → M Expr) : SubExpr → M SubExpr
  | ⟨e, p⟩ => do
    let e₂ ← lensAux g (Pos.decode p |> Array.toList) e
    return ⟨e₂, p⟩

open Except in
/-- Get the raw subexpression without performing any instantiation. -/
private def viewCoordRaw: Nat → Expr → Except String Expr
  | 3, e                        => error s!"Can't viewRaw the type of {e}"
  | 0, (Expr.app f _ _)       => ok f
  | 1, (Expr.app _ a _)       => ok a
  | 0, (Expr.lam _ y _ _)     => ok y
  | 1, (Expr.lam _ _ b _)     => ok b
  | 0, (Expr.forallE _ y _ _) => ok y
  | 1, (Expr.forallE _ _ b _) => ok b
  | 0, (Expr.letE _ y _ _ _)  => ok y
  | 1, (Expr.letE _ _ a _ _)  => ok a
  | 2, (Expr.letE _ _ _ b _)  => ok b
  | 0, (Expr.proj _ _ b _)    => ok b
  | n, (Expr.mdata _ a _)     => viewCoordRaw n a
  | c, e                        => error s!"Bad coordinate {c} for {e}"

open Except in
/-- Given a valid SubExpr, will return the raw current expression without performing any instantiation.
If the SubExpr has a type subexpression coordinate then will error. -/
def viewRaw (s : SubExpr) : Except String Expr :=
  aux s.expr s.pos.decode.toList
  where
    aux (e : Expr)
      | head :: tail =>
        match viewCoordRaw head e with
        | ok e => aux e tail
        | error m => error m
      | [] => ok e

/-- Runs `k` on the given coordinate, including handling binders properly.
The subexpression value passed to `k` is not instantiated with respect to the
array of free variables. -/
private def viewCoordAux (k : Array Expr → Expr → M α) (fvars: Array Expr) : Nat → Expr → M α
  | 3, _                        => throwError "Internal: Types should be handled by viewAux"
  | 0, (Expr.app f _ _)       => k fvars f
  | 1, (Expr.app _ a _)       => k fvars a
  | 0, (Expr.lam _ y _ _)     => k fvars y
  | 1, (Expr.lam n y b c)     => withLocalDecl n c.binderInfo (y.instantiateRev fvars) fun x => k (fvars.push x) b
  | 0, (Expr.forallE _ y _ _) => k fvars y
  | 1, (Expr.forallE n y b c) => withLocalDecl n c.binderInfo (y.instantiateRev fvars) fun x => k (fvars.push x) b
  | 0, (Expr.letE _ y _ _ _)  => k fvars y
  | 1, (Expr.letE _ _ a _ _)  => k fvars a
  | 2, (Expr.letE n y a b _)  => withLetDecl n (y.instantiateRev fvars) (a.instantiateRev fvars) fun x => k (fvars.push x) b
  | 0, (Expr.proj _ _ b _)    => k fvars b
  | n, (Expr.mdata _ a _)     => viewCoordAux k fvars n a
  | c, e                        => throwError "Invalid coordinate {c} for {e}"

private def viewAux (k : Array Expr → Expr → M α) (fvars : Array Expr) : List Nat → Expr → M α
  | [],         e => k fvars <| e.instantiateRev fvars
  | 3::tail,    e => do
    let y ← inferType <| e.instantiateRev fvars
    viewAux (fun otherFvars => k (fvars ++ otherFvars)) #[] tail y
  | head::tail, e => viewCoordAux (fun fvars => viewAux k fvars tail) fvars head e

/-- Runs `k fvars s` where `s` is the expression pointed to by the given SubExpr
and fvars are the free variables for the binders that `s` is under.
`s` is already instantiated with respect to these.
The behaviour is analogous to `Lean.Meta.forallTelescope`. -/
def view (k : Array Expr → Expr → M α) : SubExpr → M α
  | ⟨e, p⟩ => viewAux k #[] p.decode.toList e

private def foldAncestorsAux (k : Array Expr → Expr → Nat → α → M α) (acc : α) (address : List Nat) (fvars : Array Expr) (current : Expr) : M α :=
  match address with
  | [] => return acc
  | 3 :: tail => do
    let current := current.instantiateRev fvars
    let y ← inferType current
    let acc ← k fvars current 3 acc
    foldAncestorsAux (fun otherFvars => k (fvars ++ otherFvars)) acc tail #[] y
  | head :: tail => do
    let acc ← k fvars (current.instantiateRev fvars) head acc
    viewCoordAux (foldAncestorsAux k acc tail) fvars head current

/-- Folds over the strict ancestor superexpressions of the given subexpression, starting at the root expression and working down.
The fold function is given the newly instantiated free variables, the ancestor subexpression, and the coordinate
that will be explored next.-/
def foldAncestors (k : Array Expr → Expr → Nat → α → M α) (init : α) (s : SubExpr) : M α :=
  foldAncestorsAux k init s.pos.decode.toList #[] s.expr

/-- Returns true if the selected subexpression is the topmost one.-/
def isTop (s : SubExpr) : Bool := s.pos.isTop

open Except

/-- Refocus subexpression on parent subexpression. -/
def up (s : SubExpr) : Except String SubExpr :=
  if s.isTop then error "already at the top" else ok <| s.mapPos Pos.pop

def up! (s : SubExpr) : SubExpr := s.up.get!

def viewRaw! (s : SubExpr) := s.viewRaw.get!

/-- Checks whether the Subexpr is well-formed. -/
def validateNoTypes (s : SubExpr) := s.viewRaw *> pure ()

private def downAux (test : Expr → Bool) (coord : Nat) (s : SubExpr) :  Option SubExpr :=
  if test s.viewRaw! then some {s with pos := s.pos.push coord} else none

def downFn := downAux Expr.isApp 0
def downArg := downAux Expr.isApp 1
def downLamDomain := downAux Expr.isLambda 0
def downLamBody   := downAux Expr.isLambda 1
def downForallDomain := downAux Expr.isForall 0
def downForallBody := downAux Expr.isForall 1

/-- Gets all of the strict parent subexpressions -/
def ancestorsRaw (s : SubExpr) : List SubExpr := Id.run do
  let mut acc := []
  let mut x := s
  while ¬ x.isTop do
    x ← x.up!
    acc ← x :: acc
  return acc

end SubExpr

end Lean
