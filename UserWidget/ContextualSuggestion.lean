import Lean
import Lean.Server.Requests
import Lean.Server.Rpc
import UserWidget.SubExpr
import UserWidget.RpcHelpers

-- [todo] these functions must exist somewhere but not sure what they are called

def List.chooseM [Monad M] [∀ α, OrElse (M α)] (f : α → M β) : List α → M (List β)
  | [] => return []
  | head :: tail => ((List.cons <$> f head) <|> pure id) <*> chooseM f tail

def List.collectM [Monad M] (f : α → M (List β)) : List α → M (List β)
  | [] => return []
  | head :: tail => pure List.append <*> f head <*> collectM f tail

-- [todo] surely in core somewhere? It's not. Maybe for the same reason that Option is not a Monad.
-- Lake does have the instance though.
instance : Monad Task := {
  map := Task.map
  pure := Task.pure
  bind := Task.bind
}

namespace Lean.Server
-- [todo] probably put this in core?
#synth Monad Task
#check Task.map
#check MonadError
#check MonadExcept
#check RequestTask

namespace RequestTask

instance : Monad RequestTask  := show Monad (ExceptT RequestError Task) by infer_instance

end RequestTask
#check RequestM.bindTask
def RequestM.bindRequestTask (t : RequestTask α) (f : α → RequestM (RequestTask β)) : RequestM (RequestTask β) := do
  let ctx ← read
  EIO.bindTask t (fun
    | Except.error e => throw e
    | Except.ok a => f a ctx
  )
#check EStateM.adaptExcept
-- def RequestM.liftIO (m : IO α) : RequestM (α)
--   | ctx => EStateM.adaptExcept Coe.coe m

end Lean.Server


namespace Lean.Widget

open Lean Server Core Meta FileWorker Elab Tactic

deriving instance ToJson, FromJson for Lean.FVarId
/-- Selects a target or hypothesis in a goal

See also Lean.Elab.Tactic.Location -/
inductive GoalLocation
  | entire
  | targetType
  | hypothesisIdentifier (id : FVarId)
  | hypothesisValue (id : FVarId)
  | hypothesisType (id : FVarId)
  deriving Inhabited, ToJson, FromJson, BEq

structure ContextualSuggestionQueryRequest where
  pos : Lean.Lsp.TextDocumentPositionParams
  goalIndex: Nat
  goalLoc : GoalLocation
  subexprPos: Lean.PrettyPrinter.Delaborator.Pos := 1
  deriving ToJson, FromJson


structure SuggestionBase where
  display : String
  insert : String -- [todo] one day make this syntax
  deriving ToJson, FromJson

/-- This is a suggestion that is displayed to the user.

There is some potential to make this more elaborate in the future, eg it could prompt
a set of goals. -/
structure Suggestion extends SuggestionBase where
  goals : InteractiveGoals
  deriving RpcEncoding

structure ContextualSuggestionQueryResponse where
  completions : Array Suggestion
  deriving RpcEncoding

instance : EmptyCollection ContextualSuggestionQueryResponse := ⟨{completions := #[]}⟩

open Lean.Elab.Tactic Lean.Server RequestM Elab

/-- The idea is that this is everything you should need to run a tactic.-/
structure TacticStateInfo extends ContextInfo where
  main : MVarId
  goals : List MVarId
  elaborator: Name
  /-- The tactic that this is the syntax for. -/
  stx : Syntax

def TacticStateInfo.updateState (ts : Tactic.State) (ms : Meta.State) (tsi : TacticStateInfo) : TacticStateInfo :=
  {tsi with goals := ts.goals, mctx := ms.mctx}

#check ContextInfo.runMetaM
#check Tactic.run
#check MetaM.run
#check CoreM.toIO
#check CoreM.run'
#check getInteractiveGoals
#check TermElabM
#check Tactic.getGoals
#check Lean.Meta.intros

open Core Meta Server Tactic

def SuggestionProvider : Type := ContextualSuggestionQueryRequest → TacticM (List (TacticM (SuggestionBase)))
open Lean.PrettyPrinter.Delaborator
def introSuggestionProvider : SuggestionProvider
  | req => do
    guard <| req.goalLoc != GoalLocation.targetType
    guard <| req.goalIndex == 0 -- [todo] how to write tactics that act on other goals?
    let goal :=  (← getGoals).get! req.goalIndex
    let goalType := (← getMVarDecl goal).type
    let s : SubExpr := ⟨goalType, req.subexprPos⟩
    let rootBinder ← s.view (fun _ => binder)
    let abovePis ← (s.foldAncestors (fun fvars e i a => do
      guard (i == 0)
      match e with
      | Expr.forallE n y b _ => return a.push (n,y)
      | _ => failure
    ) #[])
    return [do
      let stx ← `(tactic| intros)
      Lean.Elab.Tactic.evalIntros stx
      return {display := "intros", insert := toString stx}
    ]


  where binder : Expr → TacticM Name
    | (Expr.forallE n y b _) => pure n
    | _ => failure
#check Exception
#check IO


/-- This runs the given tactic with the state given in TacticStateInfo and returns the output info.-/
def runTacticM (tsi : TacticStateInfo) (t : TacticM α) : IO (α × TacticStateInfo) := do
  let mctx := tsi.mctx
  let g :: _ := tsi.goals
    | throwThe IO.Error $ IO.Error.userError "goal state is bad"
  let lctx := mctx.getDecl g |>.lctx
  let (((a, tacticState), metaState), coreState) ←
    t {main := tsi.main, elaborator := tsi.elaborator}
    |>.run {goals := tsi.goals}
    |>.run'
    |>.run {lctx := lctx} {mctx := mctx}
    |>.toIO { options := tsi.options, currNamespace := tsi.currNamespace, openDecls := tsi.openDecls}
            { env := tsi.env, ngen := tsi.ngen}
  return (a, tsi.updateState tacticState metaState)

-- [todo] make this an attribute
def suggestionProviders : List SuggestionProvider :=
  [introSuggestionProvider]

def runSuggestionProviders (tsi : TacticStateInfo) (query : ContextualSuggestionQueryRequest) : IO (List Suggestion) := do
  -- [todo] each s might be a long-running computation (eg finding all of the lemmas which may apply.)
  suggestionProviders.collectM fun provider => do
    match (← EIO.toIO' (runTacticM tsi (provider query))) with
    | Except.error e => return []
    | Except.ok (suggestions, tsi) => do
      -- [todo] the idea is that the suggestions tactics that you get back might be long-running operations.
      let suggestions : List Suggestion ← suggestions.chooseM fun suggestion => do
        let (suggestion, tsi) ← runTacticM tsi suggestion
        let goals ←  tsi.toContextInfo.runMetaM {} <| tsi.goals.mapM fun g =>
          Meta.withPPInaccessibleNames (goalToInteractive g)
        return {suggestion with goals := {goals := goals.toArray}}
      return suggestions

#check IO.asTask

-- See also
#check getInteractiveGoals

def tacticStateOfGoalsAtResult : GoalsAtResult → TacticStateInfo
  | { ctxInfo := ci, tacticInfo := ti, useAfter := useAfter, .. } =>
    let mctx := if useAfter then ti.mctxAfter else ti.mctxBefore
    let goals := if useAfter then ti.goalsAfter else ti.goalsBefore
    { ci with mctx := mctx, goals := goals, main := goals.get! 0, elaborator := ti.elaborator, stx := ti.stx}

#check withWaitFindSnap
/-- Similar to Lean.Server.getInteractiveGoals.  -/
def getTacticStateInfo (pos : Lean.Lsp.TextDocumentPositionParams) : RequestM (RequestTask (List TacticStateInfo)) := do
  let doc ← readDoc
  let text := doc.meta.text
  let hoverPos := text.lspPosToUtf8Pos pos.position
  -- NOTE: use `>=` since the cursor can be *after* the input
  withWaitFindSnap doc (fun s => s.endPos >= hoverPos)
    (notFoundX := return []) fun snap => do
      let goalsat := snap.infoTree.goalsAt? doc.meta.text hoverPos
      let ts := goalsat.map tacticStateOfGoalsAtResult
      return ts

#check GoalsAtResult
#check ContextInfo
#check CodeWithInfos
#check Lean.Server.RequestTask

@[rpc]
def queryContextualSuggestions (args : ContextualSuggestionQueryRequest) : RequestM (RequestTask ContextualSuggestionQueryResponse) := do
  let tsis ← getTacticStateInfo args.pos
  RequestM.bindRequestTask tsis fun tsis => do
    let tsi :: _ := tsis | return (pure ∅)
    -- [todo] idk what the other TacticStateInfos are doing
    let cs ← runSuggestionProviders tsi args
    return pure {completions := cs.toArray}

end Lean.Widget