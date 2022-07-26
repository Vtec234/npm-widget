import Lake
open System Lake DSL

package UserWidget

target packageLock : FilePath :=
  let packageFile := inputFileTarget <| __dir__ / s!"widget/package.json"
  let packageLockFile := __dir__ / s!"widget/package-lock.json"
  fileTargetWithDep packageLockFile packageFile fun _srcFile => do
    proc {
      cmd := "npm"
      args := #["install"]
      cwd := some <| __dir__ / "widget"
    }

def tsxTarget (tsxName : String) : FileTarget :=
  let jsFile := __dir__ / s!"widget/dist/{tsxName}.js"
  let deps : Array FileTarget := #[
    inputFileTarget <| __dir__ / s!"widget/src/{tsxName}.tsx",
    inputFileTarget <| __dir__ / s!"widget/rollup.config.js",
    packageLock.target
  ]
  fileTargetWithDepArray jsFile deps fun _srcFile => do
    proc {
      cmd := "npm"
      args := #["run", "build", "--", "--tsxName", tsxName]
      cwd := some <| __dir__ / "widget"
    }

target staticHtml : FilePath := tsxTarget "staticHtml"
target rubiks : FilePath := tsxTarget "rubiks"
target squares : FilePath := tsxTarget "squares"

@[defaultTarget]
lean_lib UserWidget
