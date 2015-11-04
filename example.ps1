$currdir = ''
if ($MyInvocation.MyCommand.Path) {
    $currdir = Split-Path $MyInvocation.MyCommand.Path
} else {
    $currdir = $pwd -replace '^\S+::',''
}

import-module (join-path $currdir flancy.psd1) -Force

$url = "http://localhost:8001"

new-flancy -url $url -webschema @(
    Get  '/' {
        "Welcome to Flancy!"
    }
    Get  '/process' {
        Get-Process | select name, id, path | ConvertTo-Json 
    }
    Post '/process' {
        $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
        Start-Process $processname
    }
    Get '/process/{name}' {
        get-process $parameters.name |convertto-json -depth 1
    }
    Get '/prettyprocess' { 
        Get-Process | ConvertTo-HTML name, id, path 
    }
)

Invoke-RestMethod -Uri http://localhost:8001/process -Headers @{'Accept'='application/json';'Content-Type'='application/json'} #V3 and ealier you cannot use these headers - it will work without them though
Invoke-RestMethod -Uri http://localhost:8001/process -Method Post -Body "Notepad" -Headers @{'Accept'='application/json'} #V3 and ealier you cannot use these headers - it will work without them though
Invoke-RestMethod -Uri http://localhost:8001/process/notepad 
start http://localhost:8001
start http://localhost:8001/prettyprocess
