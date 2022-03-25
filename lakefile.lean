import Lake
open System Lake DSL

def jsTarget (pkgDir : FilePath) : FileTarget :=
  let jsFile := pkgDir / "widget/dist/index.js"
  let srcFiles := inputFileTarget <| pkgDir / "widget/src/index.tsx"
  fileTargetWithDep jsFile srcFiles fun srcFile => do
    proc { 
      cmd := "npm"
      args := #["run", "build"]
      cwd := some <| pkgDir / "widget"
    }

package UserWidget (pkgDir) {
  extraDepTarget := jsTarget pkgDir |>.withoutInfo
  defaultFacet := PackageFacet.oleans
  -- add configuration options here
}
