import Lake
open System Lake DSL

package UserWidget

def tsxTarget (tsxName : String) : FileTarget :=
  let jsFile := __dir__ / s!"widget/dist/{tsxName}.js"
  let srcFiles := inputFileTarget <| __dir__ / s!"widget/src/{tsxName}.tsx"
  fileTargetWithDep jsFile srcFiles fun _srcFile => do
    proc {
      cmd := "npm"
      args := #["install"]
      cwd := some <| __dir__ / "widget"
    }
    proc {
      cmd := "npm"
      args := #["run", "build"]
      cwd := some <| __dir__ / "widget"
    }

target staticHtml : FilePath := tsxTarget "staticHtml"
target rubiks : FilePath := tsxTarget "rubiks"
target squares : FilePath := tsxTarget "squares"

@[defaultTarget]
lean_lib UserWidget
