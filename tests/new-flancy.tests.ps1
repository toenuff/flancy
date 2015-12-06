$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
add-type -path "$here\..\nancy\Nancy.dll"
add-type -path "$here\..\nancy\Nancy.Hosting.Self.dll"
import-module "$here\..\flancy.psd1"

Describe "New-Flancy default error" {
    It "Throws an error when new-flancy is called with a url other than localhost without the -Public switch" {
        {New-Flancy -url "http://$(hostname):8000/"} |Should Throw
    }
}

Describe "New-Flancy expected -Path errors" {
    It "Throws an error when the c-drive is used by path" {
        {New-Flancy -Path c:\}
    }

    It "Throws an error when the users home directory is used by the path parameter" {
        {New-Flancy -Path "{0}\documents" -f $env:USERPROFILE}
    }
}

Describe "New-Flancy default behavior" {
    It "Does not throw an error when New-Flancy is used by default" {
        {New-Flancy} |should not throw
    }
    It "Creates a web server on port 8000 by default returning Hello World! from the / route" {
        Invoke-RestMethod http://localhost:8000 |Should Be "Hello World!"
    }
}


