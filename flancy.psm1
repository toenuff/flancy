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
 Webschema takes a collection of hashes.  Each element in the hash represents a different route or static content requested by the client.  For routes, the three values used in the hash are path, method, and script.  These hashes are abstracted by a DSL that you may use to build the hash.  For static content, the values are path, source, and type where type can be either 'staticfile' or 'staticdirectory'

 method defines the HTTP method that will be used by the client to get to the route.

 path defines the address in the url supplied by the client after the http://host:port/ part of the address.  Paths support parameters allowed by Nancy.  For example, if you your path is /process/{name}, the value supplied by the requestor for {name} is passed to your script.  You would use the $parameters special variable to access the name property.  In the /process/{name} example, the property would be $parameters.name in your script.

 script is a scriptblock that will be executed when the client requests the path.  The code will be routed to this scriptblock.  The scriptblock has a special variable named $parameters that will accept client parameters.  It also contains a $request special variable that contains the request info made by the client.  The $request variable can be used to read post data from the client with the following example:

 $data = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()

 Here is an example of creating the webschema with the DSL:
 $webschema = @(
     Get  '/' { "Welcome to Flancy!" }
     Get  '/process' { Get-Process | select name, id, path | ConvertTo-Json }
     Post '/process' {
             $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
             Start-Process $processname
     }
     Get '/process/{name}' { get-process $parameters.name |convertto-json -depth 1 }
     Get '/prettyprocess' { Get-Process | ConvertTo-HTML name, id, path }
     staticfile      '/index.html' '/content/index.html'
     staticdirectory '/content'    '/content/files'
 )


 Here is an example of the raw data that the above DSL creates.  This may also be passed to -webschema:

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
     },@{
        path = '/index.html'
        source = '/content/index.html'
        type = 'staticfile'
     },@{
        path = '/content'
        source = '/content/files'
        type = 'staticdirectory'
     }
 )

 .Parameter Path
 This parameter runs the flancy web server in that directory. 
 This is a useful parameter when using staticfile or staticdirectory in your webschema.
 
 For example, if -path is set to c:\content, then staticfile /index.html /stuff.html would serve c:\content\stuff.html when a request is made for /index.html

 By default, flancy will set Path to be your current directory.

 Path should either be an empty directory or a directory serving up static content.  You will receive an access denied error if you try to use a Path that has hidden directories or links that would give you an error if you ran get-childitem -force.  For example, this is common in c:\users\username\documents or root drives such as c:\ or d:\.  Note: By default when running flancy in a job, you will see this error because jobs start in c:\users\username\documents.  You must use the -Path parameter to get around this error when running Flancy in a job.

 .Parameter Public
 This allows you to use have your web server use a hostname other than localhost.  Assuming your firewall is configured correctly, you will be able to serve the web calls over a network. 


 This will require admin privileges to run.  If you do not have admin privs, a prompt will ask you if you would like to elevate.  If you choose to do this, the server will have the following run as admin.  This will allow users to serve on port 8000 from this server:

 netsh http urlacl add url='http://+:8000' user=everyone

 If you have already run your own netsh command, it will not create a new one.  For example, if you want
 to serve on http://server1:8000 with your service account named "flancyservice", you could run netsh as
 follows instead of allowing New-Flancy to create a "+:8000 user=everyone" urlacl.

 netsh http urlacl add url='http://server1:8000' user=flancyservice

 .Parameter Passthru
 Returns the flancy object.  This is generally not needed by the other cmdlets.

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
    Get '/'              { "Welcome to Flancy!" }
    Get '/process'       { get-process |select name, id, path |ConvertTo-Json }
    Get '/prettyprocess' { Get-Process |ConvertTo-HTML name, id, path }
    }
 )

 The above illustrates how you can set up multiple paths in a flancy project.  It also illustrates how to return text, create a web service that returns JSON, and display HTML visually.

 The above creates three routes that can be accessed by a client (run on the server this was run on because the public switch was not used):
 http://localhost/
 http://localhost/process
 http://localhost/prettyprocess
 
 .Example
 New-Flancy -url http://localhost:8000 -webschema @(
    Post '/startprocessbypost' {
       $processname = (new-Object System.IO.StreamReader @($Request.Body, [System.Text.Encoding]::UTF8)).ReadToEnd()
       Start-Process $processname
    } 
    Get '/startprocessbyparameter/{name}' { start-process $parameters.name }
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
        [ValidateScript({
            $HttpMethods =  'Delete', 'Get', 'Head', 'Options', 'Post', 'Put', 'Patch'

            $_ | ForEach-Object {
			    if($_.GetType().GetInterfaces().Name -notcontains 'IDictionary')
                {
				    throw 'One of the the supplied objects is not a dictionary.'
			    }

                if ($_.method) {
                    $PropSet = 'path', 'method', 'script'
                    $NonValidHttpMethods = Compare-Object -ReferenceObject $HttpMethods -DifferenceObject ($_.Method -as [array]) |
                        Where-Object {$_.SideIndicator -eq '=>'} |
                            Select-Object -ExpandProperty InputObject
                    if($NonValidHttpMethods)
                    {
                        throw "Not valid HTTP method(s): $($NonValidHttpMethods -join ', ')"
                    }
                    if(!($_.Script -is [scriptblock] -or $(try{[scriptblock]::Create($_.Script)}catch{$false})))
                    {
                        throw "Not valid 'script' property: $($_.Script)"
                    }
                } else {
                    # Currently only other values are staticfile/staticdirectory
                    # Can add more validation if we want to here
                    $PropSet = 'path', 'type', 'source'
                }

                $MissingProps = Compare-Object -ReferenceObject $PropSet -DifferenceObject ($_.Keys -as [array]) |
                    Where-Object {$_.SideIndicator -eq '<='} |
                        Select-Object -ExpandProperty InputObject

                if($MissingProps)
                {
                    throw "One of the the supplied objects is missing following property(ies): $($MissingProps -join ', ')"
                }

                $EmptyProps = $_.GetEnumerator() | Where-Object {!$_.Value} | Select-Object -ExpandProperty Name
                if($EmptyProps)
                {
                    throw "Empty properties are not allowed: $($EmptyProps -join ', ')"
                }

                foreach ($prop in $PropSet){
                    if(($_.$prop -as [array]).Count -ne 1)
                    {
                        throw "Multiple values in properties are not allowed: $($_.$prop -join ', ')"
                    }
                }


                $ValidUri = $_.Path -as [System.URI]
                if(!($ValidUri -and !$ValidUri.IsAbsoluteUri))
                {
                    throw "Not valid 'path' property: $($_.Path)"
                }

            }
            $true
        })]
        [ValidateNotNullOrEmpty()]
        [object[]] $webschema = @(@{path='/';method='Get';script = {"Hello World!"}}),
        [switch] $Passthru,
        [switch] $Public,
        [Parameter(Mandatory=$false)]
        [string] $Path
    )
    if (!$path) {
        $path = join-path ([System.io.path]::gettemppath()) "flancy"
        if (!(Test-Path $path)) {
            mkdir $path |out-null
        }
    } elseif (!(Test-Path $path)) {
        throw "The path to start from does not exist"
        break
    }
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
using Nancy.Conventions;

namespace Flancy {
    public class Module : NancyModule
    {
        public PowerShell shell = PowerShell.Create();
        public Module()
        {
            StaticConfiguration.DisableErrorTraces = false;

"@
    $routes = ''
    foreach ($entry in ($webschema |?{$_.method})) {
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
"@
    $code += @"
    public class CustomRootPathProvider : IRootPathProvider
    {
        public string GetRootPath()
        {
            return @"$path";
        }
    }

"@
    $code += @"

    public class CustomBootstrapper : DefaultNancyBootstrapper
    {
        protected override IRootPathProvider RootPathProvider
        {
            get {return new CustomRootPathProvider();}
        }
        protected override void ConfigureConventions(NancyConventions conventions)
        {
            base.ConfigureConventions(conventions);

"@
    $staticroutes = $webschema |?{$_.type -match 'static(file|directory)'}
    foreach ($entry in $staticroutes) {
        switch ($entry.type) {
            'staticfile' {
                $code += 'conventions.StaticContentsConventions.AddFile("{0}", "{1}");' -f $entry.path, $entry.source
                $code += "`r`n"
                break
            }
            'staticdirectory' {
                $code += 'conventions.StaticContentsConventions.AddDirectory("{0}", "{1}");' -f $entry.path, $entry.source
                $code += "`r`n"
                break
            }
            default {
                Write-Verbose "Unknown entry type - not staticfile nor staticdir: $($entry.type)"
            }
        }
    }
    $code += @"
        }
    }

"@

    $code+=@"

    public class Flancy 
    {
        private NancyHost host;
        private Uri uri;

        private string _CodeBehind, _nancyDLL, _nancySelfDLL, _URL, _Path;
        private Object _Webschema, _StaticRoutes;
        private bool _Public;

        // Set Read-Only properties in order of appearance when viewing the object
        public string NancyDLLPath      {get {return this._nancyDLL;}}
        public string NancySelfDLLPath  {get {return this._nancySelfDLL;}}
        public Object Webschema         {get {return this._Webschema;}}
        public Object StaticRoutes      {get {return this._StaticRoutes;}}
        public string Code              {get {return this._CodeBehind;}}
        public string URL               {get {return this._URL;}}
        public string Path              {get {return this._Path;}}
        public bool PublicServer        {get {return this._Public;}}

        public Flancy(string url, string nancydll, string nancyselfdll, Object webschema, string path, Object staticroutes, string codebehind, bool ispublic) {
            var config = new HostConfiguration();

"@
    if ($Public) {
        $code+= " "*12 + "config.UrlReservations.CreateAutomatically = true;`r`n"

    }
    else {
        $code+= " "*12 + "config.RewriteLocalhost = false;`r`n"
        $code += " "*12 + "config.UrlReservations.User = System.Security.Principal.WindowsIdentity.GetCurrent().Name;`r`n"
    }
    $code += @"

            uri = new Uri(url);
            this.host = new NancyHost(config, uri);
            this._nancyDLL = nancydll;
            this._nancySelfDLL = nancyselfdll;
            this._URL = url;
            this._Webschema = webschema;
            this._Path = path;
            this._StaticRoutes = staticroutes;
            this._CodeBehind = codebehind;
            this._Public = ispublic;
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

    try {
        add-type -typedefinition $code -referencedassemblies @($nancydll, $nancyselfdll, $MicrosoftCSharp)
        $flancy = new-object "flancy.flancy" -argumentlist $url, $nancydll, $nancyselfdll, $webschema, $Path, $staticroutes, $code, $Public
    } catch {
        if ($_.FullyQualifiedErrorId -match 'TYPE_ALREADY_EXISTS') {
            Write-Error "Flancy definition already exists.  You need to create a new PowerShell session in order to create a new definition"
            throw $_.exception
        }
        function Unwind-Exception {
            Param($Exception)

            Write-Error -Exception $Exception
            if ($VerbosePreference -ne 'silentlycontinue') {
                $Exception.PsObject.Properties | ForEach-Object {
                        $_.Name, "$($_.Value)", [System.Environment]::NewLine | Write-Verbose 
                }
            }

            if($Exception.InnerException)
            {
                Unwind-Exception $Exception.InnerException
            }
        }

        if ($_.Exception.InnerException.InnerException.InnerException.Message -match 'access to') {
            write-error "Access denied error.  Make sure you are using the -Path parameter to point to a directory where you have complete control and no hidden directories"
            throw $_.Exception.InnerException.InnerException.InnerException.Message
        }

        $_.Exception.InnerException.InnerException.InnerException |select *
        Unwind-Exception $_.Exception.InnerException
        throw "Can't create Flancy! Examine exceptions above or run 'New-Flancy' with '-Verbose' switch to get more details."
    }
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

<#
.Synopsis
   Adds an endpoint to handler GET requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-GetHandler -Path "/Process" -Script { Get-Process | ConvertTo-Json } 
.EXAMPLE
   Get "/Process" { Get-Process | ConvertTo-Json } 
#>
function Add-GetHandler {
    param(
    [string]$Path, 
    [ScriptBlock]$Script)

    @{
        Path=$Path;
        Method="Get";
        Script=$Script;
    }
}

<#
.Synopsis
   Adds an endpoint to handler POST requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-PostHandler -Path "/Process" -Script { Start-Process $Name } 
.EXAMPLE
   Post"/Process" { Start-Process $Name } 
#>
function Add-PostHandler {
    param(
    [string]$Path, 
    [ScriptBlock]$Script)

    @{
        Path=$Path;
        Method="Post";
        Script=$Script;
    }
}

<#
.Synopsis
   Adds an endpoint to handler DELETE requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-DeleteHandler -Path "/Process/{id}" -Script { Stop-Process $Parameters.Id } 
.EXAMPLE
   Delete "/Process/{id}" { Stop-Process $Parameters.Id } 
#>
function Add-DeleteHandler {
    param(
    [string]$Path, 
    [ScriptBlock]$Script)

    @{
        Path=$Path;
        Method="Delete";
        Script=$Script;
    }
}


<#
.Synopsis
   Adds an endpoint to handler PUT requests.
.DESCRIPTION
   Long description
.EXAMPLE
   Add-PutHandler -Path "/Service/{name}/{status}" -Script { Set-Service -Name $Parameters.Id -Status $Parameters.Status  } 
.EXAMPLE
   Put "/Service/{name}/{status}" { Set-Service -Name $Parameters.Id -Status $Parameters.Status  } 
#>
function Add-PutHandler {
    param(
    [string]$Path, 
    [ScriptBlock]$Script)

    @{
        Path=$Path;
        Method="Put";
        Script=$Script;
    }
}

<#
.Synopsis
   Adds a link to a static file
.DESCRIPTION
   Long description
.EXAMPLE
   Add-StaticFileHandler -Path "/index.html" -Source "/files/index.html"
#>
function Add-StaticFileHandler {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path, 
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Source)

    @{
        Type='StaticFile'
        Path=$Path
        Source=$Source
    }
}

<#
.Synopsis
   Adds a link to a static content in a directory
.DESCRIPTION
   Long description
.EXAMPLE
   Add-StaticDirectoryHandler -Path "/images" -Source "/files/images"
#>
function Add-StaticDirectoryHandler {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path, 
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Source)

    @{
        Type='StaticDirectory'
        Path=$Path
        Source=$Source
    }
}
New-Alias -Name Get -Value Add-GetHandler
New-Alias -Name Put -Value Add-PutHandler
New-Alias -Name Post -Value Add-PostHandler
New-Alias -Name Delete -Value Add-DeleteHandler
New-Alias -Name StaticFile -Value Add-StaticFileHandler
New-Alias -Name StaticDirectory -Value Add-StaticDirectoryHandler

Export-ModuleMember -Alias get, put, post, delete, staticfile, staticdirectory `
                    -Function New-Flancy, Add-GetHandler, Add-PutHandler, Add-PostHandler,`
                     Add-DeleteHandler, Add-StaticFileHandler, Add-StaticDirectoryHandler,`
                     Stop-Flancy, Start-Flancy, Get-Flancy

