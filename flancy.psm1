$nancydll = ([Nancy.NancyModule]).assembly.location
$nancyselfdll = ([Nancy.Hosting.Self.NancyHost]).assembly.location
$MicrosoftCSharp = "Microsoft.CSharp"


$flancy = $null
 
function New-Flancy {
    param(
        [Parameter(Position=0)]
        [string] $url='http://localhost:8000',
        [Parameter(Mandatory=$false)]
        [object[]] $webschema = @(@{path='/';method='Get';script = {"Hello World!"}}),
        [switch] $Passthru
    )
    if ($SCRIPT:flancy) {
        throw "A flancy already exists.  To create a new one, you must restart your PowerShell session"
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
            uri = new Uri(url);
            this.host = new NancyHost(uri);
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
