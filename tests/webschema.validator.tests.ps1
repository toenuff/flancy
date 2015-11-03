$Here = ''
if ($MyInvocation.MyCommand.Path) {
    $Here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $Here = $PWD -replace '^\S+::',''
}

Add-Type -Path "$Here\..\nancy\Nancy.dll"
Add-Type -Path "$Here\..\nancy\Nancy.Hosting.Self.dll"
Invoke-Expression (Get-Content -Path "$Here\..\flancy.psm1" | Out-String)

$Empty = $null
$NotADictionary = 1,2,3
$EmptyProperty = @{Path = '/' ; Script = {"Hello World!"}}
$MultipleProperties = @{Path = '/';Method = 'Foo','Get' ; Script = {"Hello World!"}}
$InvalidPath = @{Path = '\\\' ; Method = 'Get' ; Script = {"Hello World!"}}
$InvalidMethod = @{Path = '/' ; Method = 'Foo' ; Script = {"Hello World!"}}
$InvalidScript = @{Path = '/' ; Method = 'Get' ; Script = '~!@#$%^&*()_+'}

Describe "Flancy web schema validator" {
    It "Should throw an error when calling New-Flancy with the custom web schema, when it's empty" {
        {New-Flancy -WebSchema $Empty} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it's not a dictionary" {
        {New-Flancy -WebSchema $NotADictionary} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when one or more propreties are empty" {
        {New-Flancy -WebSchema $EmptyProperty} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when its properties contain multiple values" {
        {New-Flancy -WebSchema $MultipleProperties} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it contains invalid 'path'" {
        {New-Flancy -WebSchema $InvalidPath} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it contains invalid 'method'" {
        {New-Flancy -WebSchema $InvalidMethod} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when its 'script' is not a scriptblock or can't be created from a supplied string" {
        {New-Flancy -WebSchema $InvalidScript} | Should Throw
    }
}