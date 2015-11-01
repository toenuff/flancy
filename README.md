[![Build status](https://ci.appveyor.com/api/projects/status/765hkbmm62j16li3?svg=true)](https://ci.appveyor.com/project/toenuff/flancy)

# Flancy - A web microframework for Windows PowerShell

Flancy comes from combing Flask (python web microframework) and [Nancy](http://nancyfx.org/) (the .NET microframework libraries used by this module).  Flask + Nancy = Flancy!

Flancy creates a standalone web server in PowerShell code.  The code is routed based on the path and verb used by the client.  Each path-verb is routed to a piece of PowerShell code that serves up the data requested.

## What is PowerShell?
An interpreted language created by Microsoft that is built on and taps into the .NET framework.

## Why?
PowerShell is a development language and one day it will be treated as such.  Alternatively, even as a non-dev automation language for sysadmins, often times a sysadmin just wants to expose PowerShell commands as easily as possible through a web request.  The aim of this project is to provide the easiest possible way to spin up an in-code web server that can be backed by PowerShell.

# Getting Started
The example script is the best way to start.  Writing a web server is sooooo ridiculously easy.  Here's the meat of how it's done:

```powershell
import-module flancy
$url = "http://localhost:8001"

new-flancy -url $url -webschema @(
    @{
        path   = '/'
        method = 'get'
        script = { "Welcome to Flancy!" }
    },@{
        path   = '/processes'
        method = 'get'
        script = { 
            $processes = Get-Process
            $processes |select name, id |convertto-json
        }
    }
)
```

One thing to note:  Because of the way that Nancy works, I cannot create new custom types on subsequent New-Flancy requests.  This means that in order to make a change to your service, you'll need to restart your PowerShell session.  Another option is to start them in jobs in order to get clean sessions without restarting.

# What's Next
A ton - I know there's a ton of bugs and things to think about.  Start logging issues and feel free to contribute (including writing tests) via pull request.

# Contribute
In order to contribute, please create a Pull Request against the devel branch.  Try to include the following:
 * In the commit, if it resolves an issue, say "Fixes #xx" where xx is the issue number or at least refer to the Issue # by specifying "#xx" somewhere in your commit.
 * If there is no test for what you have done, please try to write one
 * Ensure that all tests pass prior to submitting - tests are run by calling maketest.ps1.  You cannot run invoke-pester by itself or the tests will fail.
 * Update any relevant documentation or the example.ps1 file
