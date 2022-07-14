import Lean

def toSubscriptDigit : Nat → String
| 0 => "₀" | 1 => "₁" | 2 => "₂" | 3 => "₃" | 4 => "₄" | 5 => "₅" | 6 => "₆" | 7 => "₇" | 8 => "₈" | 9 => "₉"
| _ => panic! "not a digit"

partial def toDigits (base := 10) : Nat → Array Nat
| 0 => #[]
| n => toDigits base (n / base) |>.push (n % base)


def toSubscriptDigits : Nat → String
| n => n |> toDigits 10 |>.map toSubscriptDigit |>.toList |> String.join

open Lean Elab Tactic Meta
variable {M : Type → Type} [Monad M]  [MonadLCtx M] [MonadError M]

/-- See also LocalContext.getUnusedName. -/
def findFreeName (base : String) (used : Array Name) : M Name := do
  let lctx ← getLCtx
  if base == "" then
    throwError "base must be at least one char."
  for i in [:100] do
    let curr := base ++ toSubscriptDigits i
    if (not <| lctx.usesUserName curr) && (not (used.contains curr)) then
      return curr
  throwError "failed to find a name for `base`"

def prettyNamesForHyp  (binders : Array (Name × Expr)): TacticM (Array Name) := do
  let mut acc := #[]
  for (binderName, type) in binders do
    let mut n := binderName
    let p ← liftM $ isProp type
    if p then
      n ← findFreeName "h" acc <|> pure binderName
    else
      if n.isStr then
        n ← findFreeName binderName.getString! acc
      else
        n := binderName -- not implemented
    acc := acc.push n
  return acc
