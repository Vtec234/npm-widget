import Lean
import Lean.Server.Requests
import Lean.Server.Rpc
import UserWidget.NameMapAttribute -- [todo] use Mathlib.Meta.NameMapAttribute

-- [todo] these functions must exist somewhere but not sure what they are called

def List.chooseM [Monad M] [∀ α, OrElse (M α)] (f : α → M β) : List α → M (List β)
  | [] => return []
  | head :: tail => ((List.cons <$> f head) <|> pure id) <*> chooseM f tail

def List.collectM [Monad M] (f : α → M (List β)) : List α → M (List β)
  | [] => return []
  | head :: tail => pure List.append <*> f head <*> collectM f tail


namespace Lean.Server

namespace RequestTask

end RequestTask
-- [todo] add to core?
def RequestM.bindRequestTask (t : RequestTask α) (f : α → RequestM (RequestTask β)) : RequestM (RequestTask β) := do
  let ctx ← read
  EIO.bindTask t (fun
    | Except.error e => throw e
    | Except.ok a => f a ctx
  )
end Lean.Server

namespace Lean.Widget

open Lean Server Core Meta FileWorker Elab Tactic

deriving instance ToJson, FromJson for Lean.FVarId

structure TargetLocation where
  goalId : Name
  subexprPos : Nat

-- [todo] this probably already exists.
def liftExcept [MonadError M] [Monad M] : Except String α → M α
  | Except.ok a => pure a
  | Except.error e => throwError e

def isTargetLocation : Json → Except String (TargetLocation)
  | j => do
    let Json.arr #[j_id, Json.str "type", j_pos] := j
      | throw s!"{j} is not a goal target type location."
    return {
      goalId := (← fromJson? j_id)
      subexprPos := (← fromJson? j_pos)
    }
/-- The user clicked somewhere in the hypothesis's type. -/
def isHypothesisTypeLocation : Json → Except String (MVarId × FVarId × SubExpr.Pos)
  | j => do
    let Json.arr #[j_goalId, Json.str "hyps",  j_fvarid, "type", j_pos] := j
      | throw s!"{j} is not a hypothesis location"
    -- [todo] something's gone wrong with FromJson FVarId (multiple isntances?)
    let n : Name ← fromJson? j_fvarid
    let fvarId : FVarId := FVarId.mk n
    return (
      ← fromJson? j_goalId,
      fvarId,
      ← fromJson? j_pos
    )

structure ContextualSuggestionQueryRequest where
  pos : Lean.Lsp.TextDocumentPositionParams
  /- Ad-hoc data representing the point in the infoview that the user clicked on.
  While developing, incur some tech-debt as it is easier to do this ad-hoc then maintain two sets of interfaces. -/
  loc : Json
  deriving ToJson, FromJson

structure SuggestionBase where
  insert : String -- [todo] one day make this syntax
  display : String := insert
  deriving ToJson, FromJson

/-- This is a suggestion that is displayed to the user.

There is some potential to make this more elaborate in the future, eg it could prompt
a set of goals. -/
structure Suggestion  where
  insert : String
  display := insert
  goals : InteractiveGoals
  deriving RpcEncoding

/-- Used for dirty debugging (eg showing errors inline etc.)-/
def Suggestion.dummy (s : String) : Suggestion := {goals := ⟨#[]⟩, insert := s, display := s}

def Suggestion.ofSyntax (s : Syntax) : CoreM SuggestionBase :=
  do return {insert := toString $ ← Lean.PrettyPrinter.ppCommand (TSyntax.mk s)}

structure ContextualSuggestionQueryResponse where
  completions : Array Suggestion
  deriving RpcEncoding

instance : EmptyCollection ContextualSuggestionQueryResponse := ⟨{completions := #[]}⟩

open Lean.Elab.Tactic Lean.Server RequestM Elab

/-- The idea is that this is everything you should need to run a tactic.-/
structure TacticStateInfo extends ContextInfo where
  goals : List MVarId
  elaborator: Name
  /-- The tactic that this is the syntax for. -/
  stx : Syntax


def TacticStateInfo.runCore (info : TacticStateInfo) (c : CoreM α) : IO α := do
  let (r, _) ← CoreM.toIO c
          { options := info.options,
            currNamespace := info.currNamespace,
            openDecls := info.openDecls,
            fileMap := info.fileMap,
            fileName := Inhabited.default,
          }
          { env := info.env, ngen := info.ngen }
  return r

def TacticStateInfo.updateState (ts : Tactic.State) (ms : Meta.State) (tsi : TacticStateInfo) : TacticStateInfo :=
  {tsi with goals := ts.goals, mctx := ms.mctx}

open Core Meta Server Tactic

def SuggestionProvider : Type := ContextualSuggestionQueryRequest → TacticM (List (TacticM (SuggestionBase)))
open Lean.PrettyPrinter.Delaborator

initialize suggestionProviders : NameMapExtension Unit ←
  mkNameMapExtension Unit `suggestionProviders

syntax (name := suggestion_provider) "suggestion_provider" : attr

initialize registerBuiltinAttribute {
  name := `suggestion_provider
  descr := "Use to decorate methods for computing contextual suggestions."
  add := fun src _stx _kind => do
    suggestionProviders.add src ()
}

private unsafe def getSuggestionProvidersUnsafe [MonadEnv M] [MonadOptions M] [MonadError M] [Monad M]: M (List SuggestionProvider) := do
  let env ← getEnv
  let opts ← getOptions
  let map : NameMap Unit := SimplePersistentEnvExtension.getState suggestionProviders env
  let names : List Name := Std.RBMap.fold (fun l n _ => n :: l) [] <| map
  names.mapM (fun n => do
    match Lean.Environment.evalConstCheck SuggestionProvider env opts ``SuggestionProvider n with
    | Except.ok x => return x
    | Except.error err =>
      throwError "Failed to get constant {n}: {err}"
  )

@[implementedBy getSuggestionProvidersUnsafe]
opaque getSuggestionProviders [MonadEnv M] [MonadOptions M] [MonadError M] [Monad M]: M (List SuggestionProvider)

/-- This runs the given tactic with the state given in TacticStateInfo and returns the output info.-/
def runTacticM (tsi : TacticStateInfo) (t : TacticM α) : IO (α × TacticStateInfo) := do
  let mctx := tsi.mctx
  let g :: _ := tsi.goals
    | throwThe IO.Error $ IO.Error.userError "goal state is bad"
  let lctx := mctx.getDecl g |>.lctx
  let ((a, tacticState), metaState) ←
    t {elaborator := tsi.elaborator}
    |>.run {goals := tsi.goals}
    |>.run'
    |>.run {lctx := lctx} {mctx := mctx}
    |> TacticStateInfo.runCore tsi
  return (a, tsi.updateState tacticState metaState)

def runSuggestionProviders
  (tsi : TacticStateInfo)
  (query : ContextualSuggestionQueryRequest)
  (debugMode := false)
  : IO (List Suggestion) := do
  -- [todo] each s might be a long-running computation (eg finding all of the lemmas which may apply.)
  let providers ← tsi.runCore getSuggestionProviders
  providers.collectM fun provider => do
    match (← EIO.toIO' (runTacticM tsi (provider query))) with
    | Except.error e => return if debugMode then [Suggestion.dummy s!"provider failed: {e}"] else []
    | Except.ok (suggestions, tsi) => do
      -- [todo] the idea is that the suggestions tactics that you get back might be long-running operations.
      let suggestions : List Suggestion ← suggestions.chooseM fun suggestion => ((do
        match (← EIO.toIO' $ runTacticM tsi suggestion) with
        | Except.error e => if debugMode then return Suggestion.dummy s!"failed: {e}" else throw e
        | Except.ok (suggestion, tsi) =>
          let goals ←  tsi.toContextInfo.runMetaM {} <| tsi.goals.mapM fun g =>
            Meta.withPPInaccessibleNames (goalToInteractive g)
          return {suggestion with goals := {goals := goals.toArray}}))
      return suggestions


def tacticStateOfGoalsAtResult : GoalsAtResult → TacticStateInfo
  | { ctxInfo := ci, tacticInfo := ti, useAfter := useAfter, .. } =>
    let mctx := if useAfter then ti.mctxAfter else ti.mctxBefore
    let goals := if useAfter then ti.goalsAfter else ti.goalsBefore
    { ci with mctx := mctx, goals := goals, elaborator := ti.elaborator, stx := ti.stx}

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

@[serverRpcMethod]
def queryContextualSuggestions (args : ContextualSuggestionQueryRequest)
  : RequestM (RequestTask ContextualSuggestionQueryResponse) := do
  let tsis ← getTacticStateInfo args.pos
  RequestM.bindRequestTask tsis fun tsis => do
    let tsi :: _ := tsis | return (Task.pure <| Except.pure <| ∅)
    -- [todo] idk what the other TacticStateInfos are doing
    let cs ← runSuggestionProviders tsi args
    return Task.pure <| Except.pure <| {completions := cs.toArray}

end Lean.Widget