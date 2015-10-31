$nancydll = ([Nancy.NancyModule]).assembly.location
$nancyselfdll = ([Nancy.Hosting.Self.NancyHost]).assembly.location
$MicrosoftCSharp = "Microsoft.CSharp"


$flancy = $null
 
function New-Flancy {
<#
 .Synopsis
 Creates a web server that will invoke PowerShell code based on routes being asked for by the client.
 
 .Description
 New-Flancy creates a web server.  The web server is composed of a schema that defines the client's requests to routes where PowerShell code is executed.
 
 Under the covers, New-Flancy dynamically creates a C# class that leverages Nancy, a .NET web Microframework.  It injects powershell code as requested into a PowerShell host, retrieves the results and sends data back through the web server via the Nancy framework.

 .Parameter Url
 Specifies a url/port in the form: http://servername:xxx to listen on where xxx is the port number to listen on.  When specifying localhost with the public switch activated, it will enable listening on all IP addresses.

 .Parameter Webschema
 Webschema takes a collection of hashes.  Each element in the hash represents a different route requested by the client.  The three values used in the hash are path, method, and script.

 path defines the address in the url supplied by the client after the http://host:port/ part of the address.  Paths support parameters allowed by Nancy.  For example, if you your path is /process/{name}, the value supplied by the requestor for {name} is passed to your script.  You would use the $parameters special variable to access the name property.  In the /process/{name} example, the property would be $parameters.name in your script.

 method defines the HTTP method that will be used by the client to get to the route.

 script is a scriptblock that will be executed when the client requests the path.  The code will be routed to this scriptblock.  The scriptblock has a special variable named $parameters that will accept client parameters.  It also contains a $request special variable that contains the request info made by the client.  The $request variable can be used to read post data from the client with the following example:

 $data = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()

 Here is an example webschema:

 $webschema = @(
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


 

 .Parameter Public
 This is the list of properties that will be available to the class.  This can be thought of as a Select-Object
 method defines the 
 method defines the 
 after your get- cmdlet.  Regardless of what your cmdlet returns, only the properties listed will be visible
 when viewing the objects for the class.

 .Parameter Passthru

 .Inputs
 Collection of hashes containing the schema of the web server
 
 .Outputs
 A Web server 

 .Example
 New-Flancy

 Creates a web server listening on http://localhost:8000.  The server will respond with "Hello World!" when http://localhost:8000 is browsed to.  The server will be unreachable from outside of the server it is running on.

 .Example
 New-Flancy -Public

 Creates a web server listening on http://localhost:8000.  The server will respond with "Hello World!" when http://localhost:8000 is browsed to.  The server will be reachable from outside of the server it is running on.

 This will require admin privileges to run.  If you do not have admin privs, a prompt will ask you if you would like to elevate.  If you choose to do this, the server will have the following run as admin.  This will allow users to serve on port 8000 from this server:

 netsh http urlacl add url='http://+:8000' user=everyone

 .Example
 New-Flancy -url http://localhost:8000 -webschema @(
    @{
        path = '/'
        method = 'get'
        script = { "Welcome to Flancy!" }
    },@{
        path = '/process'
        method = 'get'
        script = {
            get-process |select name, id, path |ConvertTo-Json
        }
    },@{
        path = '/prettyprocess'
        method = 'get'
        script = {
            Get-Process |ConvertTo-HTML name, id, path
        }
    }
 )

 The above illustrates how you can set up multiple paths in a flancy project.  It also illustrates how to return text, create a web service that returns JSON, and display HTML visually.

 The above creates three routes that can be accessed by a client (run on the server this was run on because the public switch was not used):
 http://localhost/
 http://localhost/process
 http://localhost/prettyprocess
 
 .Example
 New-Flancy -url http://localhost:8000 -webschema @(
    @{
       path   = '/startprocessbypost'
       method = 'post'
       script = { 
           $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
           Start-Process $processname
        } 
    },@{
        path   = '/startprocessbyparameter/{name}'
        method = 'get'
        script = { 
            start-process $parameters.name
        }
    }
 )

 The above illustrates how the special variables $request and $parameters can be used in a scriptblock.  The above illustrates how you can start a web server that will start processes based on either the data sent in POST to the route or by leveraging the parameters in a get route.

 The script enables both of the following to work:
 Invoke-RestMethod -Uri http://localhost:8000/startprocessbyparameter/notepad
 Invoke-RestMethod -Uri http://localhost:8000/startprocessbypost -Method Post -Body "Notepad" -Headers @{'Accept'='application/json'}

 .LINK
 https://github.com/toenuff/flancy/

#>
    param(
        [Parameter(Position=0)]
        [string] $url='http://localhost:8000',
        [Parameter(Mandatory=$false)]
        [object[]] $webschema = @(@{path='/';method='Get';script = {"Hello World!"}}),
        [switch] $Passthru,
        [switch] $Public
    )
    if ($SCRIPT:flancy) {
        throw "A flancy already exists.  To create a new one, you must restart your PowerShell session"
        break
    }
    if (!$Public -and $url -notmatch '\/\/localhost:') {
        throw "To specify a url other than localhost, you must use the -Public switch"
        break
    }

    $MethodBody = '
            string command = @"function RouteBody {{ param($Parameters, $Request) {0} }}";
            this.shell.Commands.AddScript(command);
            this.shell.Invoke();
            this.shell.Commands.Clear(); 
            this.shell.Commands.AddCommand("RouteBody").AddParameter("Parameters", _).AddParameter("Request", Request);
            var output = string.Empty;
            foreach(var item in this.shell.Invoke()) 
            {{
                output += item;
            }}
            return output;
        '

    $code = @"
using System;
using System.Management.Automation;
using Nancy;
using Nancy.Hosting.Self;
using Nancy.Extensions;

namespace Flancy {
    public class Module : NancyModule
    {
        public PowerShell shell = PowerShell.Create();
        public Module()
        {
            StaticConfiguration.DisableErrorTraces = false;

"@
    $routes = ''
    foreach ($entry in $webschema) {
        $method = (Get-Culture).TextInfo.ToTitleCase($entry.method)
        if ($entry.parameters) {
            $routes += "`r`n            $method[`"$($entry.path)`"] = parameters => "
        } else {
            $routes += "`r`n            $method[`"$($entry.path)`"] = _ => "
        }
        $routes += "{try {"
        $routes += ($MethodBody -f ($entry.script -replace '"', '""'))
        $routes += "} catch (System.Exception ex) { return ex.Message; }"
        $routes += "};`r`n"
    }
    $code += $routes
    $code+=@"

        }
    }
    public class Flancy 
    {
        private NancyHost host;
        private Uri uri;
        public Flancy(string url) {
            var config = new HostConfiguration();
"@
    if ($Public) {
        $code+= "config.UrlReservations.CreateAutomatically = true;`r`n"

    }
    else {
        $code+= "config.RewriteLocalhost = false;`r`n"
        $code += "config.UrlReservations.User = System.Security.Principal.WindowsIdentity.GetCurrent().Name;`r`n"
    }
    $code += @"
            uri = new Uri(url);
            this.host = new NancyHost(config, uri);
        }
        public void Start() {
            this.host.Start();
        }
        public void Stop() {
            this.host.Stop();
        }
    }
}
"@ 

    Write-Debug $code

    add-type -typedefinition $code -referencedassemblies @($nancydll, $nancyselfdll, $MicrosoftCSharp)
    $flancy = new-object "flancy.flancy" -argumentlist $url
    try {
        $flancy.start()
        if ($flancy) {
            $SCRIPT:flancy = $flancy
            if ($Passthru) {
                $flancy
            }
        }
    } catch [Exception] {
        $_
    }
}

function Get-Flancy {
    $flancy
}

function Start-Flancy {
    if ($flancy) {
        $flancy.start()
    }
    else {
        throw "Flancy not found.  Did you successfully run New-Flancy?"
    }
}

function Stop-Flancy {
    if ($flancy) {
        $flancy.stop()
    } else {
        throw "Flancy not found.  Did you successfully run New-Flancy?"
    }
}
