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
        new-flancy -url $url -Authentication Token -webschema $webschema
        $Token = Invoke-RestMethod -Uri http://localhost:8001/authenticate -Method Post -verbose
        $token.length |should not be 0
        #$token |should not contain "\r\n"
    }
    It "should enforce authentication" {
        new-flancy -url $url -Authentication Token -webschema $webschema
        { Invoke-RestMethod -Uri http://localhost:8001/authexample -verbose } | Should throw
    }

    AfterEach {
        Stop-Flancy
    }
}
