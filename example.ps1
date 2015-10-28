$currdir = ''
if ($MyInvocation.MyCommand.Path) {
    $currdir = Split-Path $MyInvocation.MyCommand.Path
} else {
    $currdir = $pwd -replace '^\S+::',''
}

import-module (join-path $currdir flancy.psd1)

$url = "http://localhost:8001"

new-flancy -url $url -webschema @(
    @{
        path   = '/'
        method = 'Get' #currently case sensitive
        script = { "Welcome to Flancy!" }
    },@{
        path   = '/processes'
        method = 'Get' #currently case sensitive
        script = { 
            $processes = Get-Process
            $processes |select name, id |convertto-json
        }
    }
)

start $url
