$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
add-type -path "$here\..\nancy\Nancy.dll"
add-type -path "$here\..\nancy\Nancy.Hosting.Self.dll"
import-module "$here\..\flancy.psd1"

Describe "cwd=c:\" {
    It "New-Flancy should not error when the current dir is the root of the c-drive" {
        cd ("{0}\documents" -f $env:USERPROFILE)
        {New-Flancy} |should not throw
    }
}

