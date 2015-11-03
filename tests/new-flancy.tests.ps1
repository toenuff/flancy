$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}

Import-Module "$here\..\flancy.psd1" -Force

Describe "New-Flancy Defaults" {
    It "Throws an error when new-flancy is called with a url other than localhost without the -Public switch" {
        {New-Flancy -url "http://$(hostname):8000/"} |Should Throw
    }

    It "Does not throw an error when New-Flancy is used by default" {
        {New-Flancy} |should not throw
    }
    It "Creates a web server on port 8000 by default returning Hello World! from the / route" {
        New-Flancy
        Invoke-RestMethod http://localhost:8000 |Should Be "Hello World!"
    }

    AfterEach {
        Stop-Flancy
    }
}


