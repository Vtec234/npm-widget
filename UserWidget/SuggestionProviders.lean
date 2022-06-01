import UserWidget.ContextualSuggestion
import UserWidget.PrettyNameGenerator
#check MonadExcept
open Lean Elab Tactic Widget Meta PrettyPrinter Delaborator

def focusMainGoal : ContextualSuggestionQueryRequest → TacticM (MVarId × SubExpr)
  | req => do
    let goal :: _ ← getGoals | throwError "no goals"
    let loc ← liftExcept (isTargetLocation req.loc)
    if (goal.name != loc.goalId) then
      throwError "main goal does not match {loc.goalId}"
      -- [todo] how to support tactics on non-main goals?
    let goalType := (← getMVarDecl goal).type
    let s : SubExpr := ⟨goalType, loc.subexprPos⟩
    return (goal, s)

@[suggestion_provider]
def introSuggestionProvider : SuggestionProvider
  | req => do
    let (goal, s) ← focusMainGoal req
    let rootBinder ← s.view (fun _ => binder)
    let abovePis : Array (Name × Expr) ← (s.foldAncestors (fun fvars e i a => do
      if (i != 1) then throwError "not focussed on body in {e}"
      let b ← binder e
      return a.push b
    ) #[])
    let binders := abovePis.push rootBinder
    let names ← prettyNamesForHyp binders
    let ids := names.map mkIdent
    return [do
      let stx ← `(tactic| intros $ids*)
      Lean.Elab.Tactic.evalIntros stx
      Suggestion.ofSyntax stx
    ]

  where binder : Expr → TacticM (Name × Expr)
    | (Expr.forallE n y b _) => pure (n, y)
    | e => throwError "{e} is not a binder"

@[suggestion_provider]
def rflSuggestionProvider : SuggestionProvider
  | req => do
    let (goal, s) ← focusMainGoal req
    if not s.isTop then
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
    let localDecl ← getLocalDecl fvarId
    let s : SubExpr := ⟨localDecl.type, pos⟩
    if not s.isTop then
      throwError "Cases only shown at top subexpr."
      -- [todo] in the future you could do rcases etc by selecting a subexpr.
    -- throwError "run cases on {localDecl.userName}"
    return [do
      let stx ← `(tactic| cases $(mkIdent localDecl.userName))
      Lean.Elab.Tactic.evalTactic stx
      Suggestion.ofSyntax stx
    ]



/-- Just a debugging 'suggestion' where it tells you the location that the suggestion was called at. -/
def loopbackSuggestionProvider : SuggestionProvider
  | req => do
    return [do
      return {display := (toString <| req.loc), insert := "?????"}
    ]
