add-type -path "c:\nancy\nancy.dll"
add-type -path "c:\nancy\Nancy.Hosting.Self.dll"

$nancydll = ([Nancy.NancyModule]).assembly.location
$nancyselfdll = ([Nancy.Hosting.Self.NancyHost]).assembly.location

$code = @"
using System;
using System.Management.Automation;
using Nancy;
using Nancy.Hosting.Self;

namespace Flancy {
    public class HelloModule : NancyModule
    {
        public PowerShell shell = PowerShell.Create();
        public HelloModule()
        {
            StaticConfiguration.DisableErrorTraces = false;

"@
$webschema = @(
    @{
        path='/'
        method='Get'
        script = {
            "Hello World!"
        }
    },
    @{
        path='/blah'
        method='Get'
        script = {
            gps |select name, path |convertto-json
        }
    }
)
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
$h = new-object flancy.flancy -argumentlist 'http://localhost:8001'
$h.start()
