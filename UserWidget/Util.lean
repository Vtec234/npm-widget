import Lean.Elab
/- This is stuff that was in mathlib but mathlib is too unstable to depend on -/

elab (name := includeStr) "include_str " str:str : term => do
  let some str := str.isStrLit? | Lean.Elab.throwUnsupportedSyntax
  let ctx ← readThe Lean.Core.Context
  let srcPath := System.FilePath.mk ctx.fileName
  let some srcDir := srcPath.parent | throwError "{srcPath} not in a valid directory"
  let path := srcDir / str
  Lean.mkStrLit <$> IO.FS.readFile path
