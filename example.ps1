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
        method = 'Get' #currently case sensitive
        script = { "Welcome to Flancy!" }
    },@{
        path   = '/process'
        method = 'Get' #currently case sensitive
        script = { 
            Get-Process | ConvertTo-Json
        }
    },@{
        path   = '/process'
        method = 'Post' #currently case sensitive
        script = { 
            $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
            Start-Process $processname
        }
    }
)

Invoke-RestMethod -Uri http://localhost:8001/process -Headers @{'Accept'='application/json';'Content-Type'='application/json'}

Invoke-RestMethod -Uri http://localhost:8001/process -Method Post -Body "Notepad" -Headers @{'Accept'='application/json'}
