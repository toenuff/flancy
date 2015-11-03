$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
add-type -path "$here\..\nancy\Nancy.dll"
add-type -path "$here\..\nancy\Nancy.Hosting.Self.dll"
add-type -path "$here\..\nancy\Nancy.Authentication.Token.dll"
Invoke-Expression (gc "$here\..\flancy.psm1" |out-String)

$url = "http://localhost:8001"

$webschema = @(
    @{
        path   = '/authenticate'
        method = 'post'
        script = { 
            New-Token -UserName "Administrator" -Context $Context -verbose
        }
    },@{
        path   = '/authexample'
        method = 'get'
        script = { 
            $true
        }
        authRequired = $true
    }
)
Describe "New-Flancy token authentication" {
    #It "should be admin" {
    #    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") |should be $true
    #}
    It "should not throw when creating a Flancy server with Authentication set to Token" {
        {new-flancy -url $url -Authentication Token -webschema $webschema} |should not throw
    }
    It "should return a valid token" {
        $Token = Invoke-RestMethod -Uri http://localhost:8001/authenticate -Method Post -verbose
        #$token.length |should be 0
        #$token |should not contain "\r\n"
    }
    # Invoke-RestMethod -Uri http://localhost:8001/authexample  -Headers @{'Accept'='application/json';Authorization="Token $token"}
}
