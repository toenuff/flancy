# Flancy - A web microframework for Windows PowerShell

Flancy comes from combing Flask (python web microframework) and Nancy (the .NET microframework libraries used by this module).  Flask + Nancy = Flancy!

## What is PowerShell?
An interpreted language created by Microsoft that is built on and taps into the .NET framework.

## Why?
PowerShell is a development language and one day it will be treated as such.  Alternatively, even as a non-dev automation language for sysadmins, often times a sysadmin just wants to expose PowerShell commands as easily as possible through a web request.  The aim of this project is to provide the easiest possible way to spin up an in-code web server that can be backed by PowerShell.

# Getting Started
The example script is the best way to start.  Writing a web server is sooooo ridiculously easy.  Here's the meat of how it's done:

```powershell
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
```

# What's Next
A ton - I know there's a ton of bugs and things to think about.  Start logging issues and feel free to contribute (including writing tests) via pull request.  I have to figure out ways to handle posts, puts, deal with aut, etc.
