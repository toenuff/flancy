$nancydll = ([Nancy.NancyModule]).assembly.location
$nancyselfdll = ([Nancy.Hosting.Self.NancyHost]).assembly.location


$flancy = $null
 
function New-Flancy {
    param(
        [Parameter(Position=0)]
        [string] $url='http://localhost:8000',
        [Parameter(Mandatory=$false)]
        [object[]] $webschema = @(@{path='/';method='Get';script = {"Hello World!"}})
    )
    if ($SCRIPT:flancy) {
        throw "A flancy already exists.  To create a new one, you must restart your PowerShell session"
        break
    }
    $code = @"
using System;
using System.Management.Automation;
using Nancy;
using Nancy.Hosting.Self;

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
        $routes += "`r`n$($entry.method)[`"$($entry.path)`"] = _ => "
        $routes += "{`r`n"
        #$routes += "string command = `"gps |convertto-json`";`r`n";
        #$routes += "string command = `"gps |convertto-json`";`r`n";
        $routes += "string command = @`"{0}`r`n`";`r`n" -f ($entry.script -replace '"', '""')
        $routes += 'this.shell.Commands.AddScript(command);'
        $routes += "`r`n"
        $routes += 'var results = this.shell.Invoke();'
        $routes += "`r`n"
        $routes += @"
            var output = "";
            foreach (var item in results) {
                output += item;
            }
"@
        $routes += 'return output;'
        $routes += "};`r`n"
        #$code+='Get["/"] = parameters => "Suckit PowerShell World";'
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

    add-type -typedefinition $code -referencedassemblies @($nancydll, $nancyselfdll)
    $flancy = new-object "flancy.flancy" -argumentlist $url
    try {
        $flancy.start()
        if ($flancy) {
            $SCRIPT:flancy = $flancy
            $flancy
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

### TODO
### Should probably allow pipes from cmdlets and explicity flancy passing
### HTTP methods are case sensitive - need to fix automatically if entered incorrectly
### Consider validation on the webschema
