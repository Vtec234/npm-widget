import Lake
open System Lake DSL

def jsTarget (pkgDir : FilePath) : FileTarget :=
  let jsFile := pkgDir / "widget/dist/squares.js"
  let srcFiles := inputFileTarget <| pkgDir / "widget/src/squares.tsx"
  fileTargetWithDep jsFile srcFiles fun _srcFile => do
    proc {
      cmd := "npm"
      args := #["install"]
      cwd := some <| pkgDir / "widget"
    }
    proc {
      cmd := "npm"
      args := #["run", "build"]
      cwd := some <| pkgDir / "widget"
    }

package UserWidget (pkgDir) {
  extraDepTarget := jsTarget pkgDir |>.withoutInfo
  defaultFacet := PackageFacet.oleans
  -- add configuration options here
  dependencies := #[
/-     {
    name := `mathlib
    src := Source.git "https://github.com/leanprover-community/mathlib4.git" "master"
  } -/
  ]
}
