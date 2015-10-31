$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
add-type -path "$here\..\nancy\Nancy.dll"
add-type -path "$here\..\nancy\Nancy.Hosting.Self.dll"
Invoke-Expression (gc "$here\..\flancy.psm1" |out-String)

# v1 of tests - still need to write some wrappers and stuff to support multiple new-flancy calls

Describe "New-Flancy" {
    It "Throws an error when new-flancy is called with a url other than localhost without the -Public switch" {
        {New-Flancy -url "http://$(hostname):8000/"} |Should Throw
    }
}

Describe "New-Flancy basic get" {
    New-Flancy
    It "Creates a web server on port 8000 by default returning Hello World! from the / route" {
        Invoke-RestMethod http://localhost:8000 |Should Be "Hello World!"
    }
}

