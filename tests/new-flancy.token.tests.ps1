$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}

Import-Module "$here\..\flancy.psd1" -Force

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
    It "should not throw when creating a Flancy server with Authentication set to Token" {
        {new-flancy -url $url -Authentication Token -webschema $webschema} |should not throw
    }
    It "should return a valid token" {
        $Token = Invoke-RestMethod -Uri http://localhost:8001/authenticate -Method Post 
        $token.length |should not be 0
        #$token |should not contain "\r\n"
    }
    It "should enforce authentication" {
        { Invoke-RestMethod -Uri http://localhost:8001/authexample } | Should throw
    }
    it "should authenticate with token" {
        $Token = Invoke-RestMethod -Uri http://localhost:8001/authenticate -Method Post 
        Invoke-RestMethod -Uri http://localhost:8001/authexample  -Headers @{'Accept'='application/json';Authorization="Token $token"}
    }
}
