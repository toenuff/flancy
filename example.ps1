$currdir = ''
if ($MyInvocation.MyCommand.Path) {
    $currdir = Split-Path $MyInvocation.MyCommand.Path
} else {
    $currdir = $pwd -replace '^\S+::',''
}

import-module (join-path $currdir flancy.psd1) -Force

$url = "http://localhost:8001"

new-flancy -url $url -webschema @(
    @{
        path   = '/'
        method = 'get'
        script = { "Welcome to Flancy!" }
    },@{
        path   = '/process'
        method = 'get'
        script = { 
            Get-Process | select name, id, path | ConvertTo-Json
        }
    },@{
        path   = '/process'
        method = 'post'
        script = { 
            $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
            Start-Process $processname
        }
    },@{
        path   = '/process/{name}'
        method = 'get'
        script = { 
            get-process $parameters.name |convertto-json -depth 1
        }
    },@{
        path   = '/prettyprocess'
        method = 'get'
        script = { 
            Get-Process | ConvertTo-HTML name, id, path
        }
    }
)

Invoke-RestMethod -Uri http://localhost:8001/process -Headers @{'Accept'='application/json';'Content-Type'='application/json'}
Invoke-RestMethod -Uri http://localhost:8001/process -Method Post -Body "Notepad" -Headers @{'Accept'='application/json'}
Invoke-RestMethod -Uri http://localhost:8001/process/notepad 
start http://localhost:8001
start http://localhost:8001/prettyprocess
