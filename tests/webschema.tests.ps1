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

# All of the schemas are in one new-nancy call to speed up the tests.
# Ideally they should be split up so that each web request tests the single schema element, but with the overhead
# of each powershell.exe call for the hosts, it's the only way to make the tests runnable while developing.

$webschema = @(
    Get "/" { 
        "Welcome to Flancy!"
    }

    Get "/json" {
        @{ name = 'blah'; list = @(0,1,2)} |convertto-json
    }

    Post "/commandfrompost" {
        $command = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
        Get-command $command |select name, noun, verb |convertto-json
    }

    Get '/commandfromparameter/{name}' {
        $command = $parameters.name
        Get-command $command |select name, noun, verb |convertto-json
    }
    
    Put "/json" {
        
    }
    
    Delete "/json" {
        
    })

Describe "Localhost web requests against Flancy schema" {
    It "Should not throw an error when calling New-Flancy with the custom web schema" {
        {New-Flancy -url http://localhost:8001 -webschema $webschema} |should not throw
    }
    It "Returns the data supplied in the schema from a GET request to /" {
        Invoke-RestMethod http://localhost:8001 |Should Be "Welcome to Flancy!"
    }
    It "Returns raw JSON appropriately" {
        $data = Invoke-WebRequest -Uri http://localhost:8001/json -Headers @{'Accept'='application/json';'Content-Type'='application/json'}
        $data.content |should be @"
{
    "list":  [
                 0,
                 1,
                 2
             ],
    "name":  "blah"
}
"@
    }
    It "Accepts post data and passes it through to $request.body appropriately" {
        $data = Invoke-RestMethod -Uri http://localhost:8001/commandfrompost -Method Post -Body "Get-ChildItem" -Headers @{'Accept'='application/json'}
        $data.verb |should be get
        $data.noun |should be childitem
    }
    It "Accepts parameter data and passes it through to $parameters appropriately" {
        $data = Invoke-RestMethod -Uri http://localhost:8001/commandfromparameter/Set-Item -Headers @{'Accept'='application/json'}
        $data.verb |should be set 
        $data.noun |should be item
    }
    It "Accepts PUT request" {
        { Invoke-RestMethod -Uri http://localhost:8001/json -Method Put -Headers @{'Accept'='application/json'} } | Should not throw
    }
    
    It "Accepts DELETE request" {
        { Invoke-RestMethod -Uri http://localhost:8001/json -Method Delete -Headers @{'Accept'='application/json'} } | Should not throw
    }
}

