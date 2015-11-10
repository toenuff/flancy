$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}
add-type -path "$here\..\nancy\Nancy.dll"
add-type -path "$here\..\nancy\Nancy.Hosting.Self.dll"
import-module "$here\..\flancy.psd1"

Describe "Flancy web schema validator tests" {
    It "Should throw an error when calling New-Flancy with the custom web schema, when it's empty" {
        {New-Flancy -WebSchema $null} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it's not a dictionary" {
        {New-Flancy -WebSchema @(1,2,3)} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when one or more propreties are empty" {
        {New-Flancy -WebSchema @{Path = '/' ; Script = {"Hello World!"}}} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when its properties contain multiple values" {
        {New-Flancy -WebSchema @{Path = '/';Method = 'Foo','Get' ; Script = {"Hello World!"}}} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it contains invalid 'path'" {
        {New-Flancy -WebSchema @{Path = '\\\' ; Method = 'Get' ; Script = {"Hello World!"}}} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when it contains invalid 'method'" {
        {New-Flancy -WebSchema @{Path = '/' ; Method = 'Foo' ; Script = {"Hello World!"}}} | Should Throw
    }
    It "Should throw an error when calling New-Flancy with a web schema containing StaticFile, but missing source or path" {
        {New-Flancy -WebSchema @{Type='StaticFile'; source='/index.html'}} |should throw
        {New-Flancy -WebSchema @{Type='StaticFile'; path='/index.html'}} |should throw
    }
    It "Should throw an error when calling New-Flancy with a web schema containing StaticDirectory, but missing source or path" {
        {New-Flancy -WebSchema @{Type='StaticDirectory'; source='/blah'}} |should throw
        {New-Flancy -WebSchema @{Type='StaticDirectory'; path='/index.html'}} |should throw
    }
    It "Should throw an error when calling New-Flancy with the custom web schema, when its 'script' is not a scriptblock or can't be created from a supplied string" {
        {New-Flancy -WebSchema @{Path = '/' ; Method = 'Get' ; Script = '~!@#$%^&*()_+'}} | Should Throw
    }
}

# All of the schemas are in one new-nancy call to speed up the tests.
# Ideally they should be split up so that each web request tests the single schema element, but with the overhead
# of each powershell.exe call for the hosts, it's the only way to make the tests runnable while developing.

Describe "The DSL should create the same hash elements that can be used by webschema" {
    It 'Translates Get appropriately' {
        $script = {'test'}
        $testdsl = get '/' $script
        $testdsl.method |should be 'get'
        $testdsl.path   |should be '/'
        $testdsl.script |should be $script
    }
    It 'Translates Post appropriately' {
        $script = {'test'}
        $testdsl = Post '/' $script
        $testdsl.method |should be 'post'
        $testdsl.path   |should be '/'
        $testdsl.script |should be $script
    }
    It 'Translates Put appropriately' {
        $script = {'test'}
        $testdsl = Put '/' $script
        $testdsl.method |should be 'put'
        $testdsl.path   |should be '/'
        $testdsl.script |should be $script
    }
    It 'Translates Delete appropriately' {
        $script = {'test'}
        $testdsl = delete '/' $script
        $testdsl.method |should be 'delete'
        $testdsl.path   |should be '/'
        $testdsl.script |should be $script
    }
    It 'Translates StaticFile appropriately' {
        $testdsl = StaticFile '/index.html' '/files/index.html'
        $testdsl.path |should be '/index.html'
        $testdsl.type |should be 'staticfile'
        $testdsl.source |should be '/files/index.html'
    }
    It 'Translates StaticDirectory appropriately' {
        $testdsl = StaticDirectory '/target' '/files/source'
        $testdsl.path |should be '/target'
        $testdsl.type |should be 'staticdirectory'
        $testdsl.source |should be '/files/source'
    }
}

$webschema = @(
    Get '/' {
        "Welcome to Flancy!"
    }
    Get '/json' {
            @{ name = 'blah'; list = @(0,1,2)} |convertto-json
    }
    Post '/commandfrompost' {
            $command = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
            Get-command $command |select name, noun, verb |convertto-json
    }
    Get '/commandfromparameter/{name}' {
            $command = $parameters.name
            Get-command $command |select name, noun, verb |convertto-json
    }
    StaticFile '/data.html' 'content/data.html'
    StaticDirectory '/files' 'content/'
)

Describe "Localhost web requests against Flancy schema" {
    It "Should not throw an error when calling New-Flancy with the custom web schema" {
        {New-Flancy -url http://localhost:8001 -webschema $webschema -path $here} |should not throw
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
    It "Serves static content files appropriately" {
        $staticfile = join-path $here "content/data.html"
        "success" |out-file -encoding ASCII $staticfile
        Invoke-RestMethod -Uri http://localhost:8001/data.html |should be "success`r`n"
    }
    It "Serves static content directories appropriately" {
        # leverages content created for static files in last test
        Invoke-RestMethod -Uri http://localhost:8001/files/data.html |should be "success`r`n"
    }
}

