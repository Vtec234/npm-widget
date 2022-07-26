import UserWidget.ContextualSuggestion
import UserWidget.PrettyNameGenerator
open Lean Elab Tactic Widget Meta PrettyPrinter Delaborator

def focusMainGoal : ContextualSuggestionQueryRequest → TacticM (MVarId × Expr × SubExpr.Pos)
  | req => do
    let goal :: _ ← getGoals | throwError "no goals"
    let loc ← liftExcept (isTargetLocation req.loc)
    if (goal.name != loc.goalId) then
      throwError "main goal does not match {loc.goalId}"
      -- [todo] how to support tactics on non-main goals?
    let goalType := (← goal.getDecl).type
    return (goal, goalType, loc.subexprPos)

@[suggestion_provider]
def introSuggestionProvider : SuggestionProvider
  | req => do
    let (_, goalType, pos) ← focusMainGoal req
    let rootBinder ← Lean.Meta.viewSubexpr (fun _ => binder) pos goalType
    let abovePis : Array (Name × Expr) ← (Lean.Meta.foldAncestors (fun _ e i a => do
      if (i != 1) then throwError "not focussed on body in {e}"
      let b ← binder e
      return a.push b
    ) #[] pos goalType)
    let binders := abovePis.push rootBinder
    let names ← prettyNamesForHyp binders
    let ids := names.map mkIdent
    return [do
      let stx ← `(tactic| intros $ids*)
      Lean.Elab.Tactic.evalIntros stx
      Suggestion.ofSyntax stx
    ]

  where binder : Expr → TacticM (Name × Expr)
    | (Expr.forallE n y _ _) => pure (n, y)
    | e => throwError "{e} is not a binder"

@[suggestion_provider]
def rflSuggestionProvider : SuggestionProvider
  | req => do
    let (_, _, p) ← focusMainGoal req
    if not p.isRoot then
      throwError "Can only apply rfl to head goal."
    return [do
      let stx ← `(tactic| rfl)
      Lean.Elab.Tactic.evalTactic stx
      Suggestion.ofSyntax stx
    ]

@[suggestion_provider]
def casesSuggestionProvider : SuggestionProvider
  | req => do
    let goal :: _ ← getGoals | failure
    let (goalId, fvarId, pos) ← liftExcept <| isHypothesisTypeLocation req.loc
    if (goal != goalId) then
      throwError "Not working on main goal not supported yet"
    let localDecl ← fvarId.getDecl
    if not pos.isRoot then
      throwError "Cases only shown at top subexpr."
      -- [todo] in the future you could do rcases etc by selecting a subexpr.
    -- throwError "run cases on {localDecl.userName}"
    return [do
      let stx ← `(tactic| cases $(TSyntax.mk <| mkIdent localDecl.userName))
      Lean.Elab.Tactic.evalTactic stx
      Suggestion.ofSyntax stx
    ]

/-- Just a debugging 'suggestion' where it tells you the location that the suggestion was called at. -/
def loopbackSuggestionProvider : SuggestionProvider
  | req => do
    return [do
      return {display := (toString <| req.loc), insert := "?????"}
    ]
