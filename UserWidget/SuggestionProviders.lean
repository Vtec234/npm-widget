import UserWidget.ContextualSuggestion

open Lean Elab Tactic Widget Meta PrettyPrinter Delaborator

@[suggestion_provider]
def introSuggestionProvider : SuggestionProvider
  | req => do
    let goal :: _ ← getGoals | throwError "no goals"
    -- [todo] make a load of helper functions like "isGoal" etc.
    let Except.ok loc := isTargetLocation req.loc | throwError "{req.loc} is not a target location."
    if (goal.name != loc.goalId) then throwError "{goal.name} does not match {loc.goalId}"
    let goalType := (← getMVarDecl goal).type
    let s : SubExpr := ⟨goalType, loc.subexprPos⟩
    -- [todo] assert s is valid
    let rootBinder ← s.view (fun _ => binder)
    let abovePis ← (s.foldAncestors (fun fvars e i a => do
      if (i != 0) then throwError "not focussed on body in {e}"
      match e with
      | Expr.forallE n y b _ => return a.push (n,y)
      | e => throwError "expected {e} to be a forall."
    ) #[])
    return [do
      let stx ← `(tactic| intros)
      Lean.Elab.Tactic.evalIntros stx
      let insert ← ppCommand stx
      return {display := "intros", insert := toString insert}
    ]

  where binder : Expr → TacticM Name
    | (Expr.forallE n y b _) => pure n
    | e => throwError "{e} is not a binder"


/-- Just a debugging 'suggestion' where it tells you the location that the suggestion was called at. -/
def loopbackSuggestionProvider : SuggestionProvider
  | req => do
    return [do
      return {display := (toString <| req.loc), insert := "?????"}
    ]
