# This is derived from https://github.com/RamblingCookieMonster/PSDiskPart/blob/master/Tests/appveyor.pester.ps1
#
# The MIT License (MIT)
#
# Copyright (c) 2015 Warren F.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

param(
    [Parameter(Mandatory=$false)]
    [switch] $schemaonly
)

$here = ''
if ($MyInvocation.MyCommand.Path) {
    $here = Split-Path $MyInvocation.MyCommand.Path
} else {
    $here = $pwd -replace '^\S+::',''
}

# Schema test is often run - thought it would be good to offer it quickly without other tests
if ($schemaonly) {
    $tests = get-childitem (join-path $here "tests/webschema.tests.ps1")
} else {
    $tests = get-childitem (join-path $here "tests/*.tests.ps1")
}

foreach ($file in $tests ) {
    $nunitxml = $file.fullname + ".nunit.result.xml"
    $clixml = $file.fullname + ".clixml.result.xml"
    powershell.exe -noprofile -c "invoke-pester -path $($file.fullname) -outputFormat NUnitXml -OutputFile $nunitxml -passthru |export-clixml -path $clixml"
}

if ($env:APPVEYOR_JOB_ID) {
    foreach ($file in (ls (join-path $here "tests/*.nunit.result.xml"))) {
        $Address = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        $Source = $file.FullName

        "UPLOADING FILES: $Address $Source"

        (New-Object 'System.Net.WebClient').UploadFile( $Address, $Source )
    }
}
else {
    "Skipping Appveyor upload because this job is not running in Appveyor"
}

foreach ($file in (ls (join-path $here "tests/*.clixml.result.xml"))) {

}
#What failed?
$Results = @( Get-ChildItem -Path (join-path $here "tests/*.clixml.result.xml") | Import-Clixml )

$FailedCount = $Results |
    Select -ExpandProperty FailedCount |
    Measure-Object -Sum |
    Select -ExpandProperty Sum

if ($FailedCount -gt 0) {
    $FailedItems = $Results |
        Select -ExpandProperty TestResult |
        Where {$_.Passed -notlike $True}

    "FAILED TESTS SUMMARY:`n"
    $FailedItems | ForEach-Object {
        $Test = $_
        [pscustomobject]@{
            Describe = $Test.Describe
            Context = $Test.Context
            Name = "It $($Test.Name)"
            Result = $Test.Result
        }
    } |
        Sort Describe, Context, Name, Result |
        Format-List

    throw "$FailedCount tests failed."
}
