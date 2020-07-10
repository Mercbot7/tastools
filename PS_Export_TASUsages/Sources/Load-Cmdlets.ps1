$ScriptFilePath = $PSScriptRoot;
$ScriptFilePath;
$Files = Get-ChildItem -Path $ScriptFilePath -Name "*.ps1" -Exclude "Load*"

foreach ($File in $Files) {
    Write-Host "Loading $($ScriptFilePath)/$($File) ";
    . ./$File;
}