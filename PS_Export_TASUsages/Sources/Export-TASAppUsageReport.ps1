Class OMServerFQDNs : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $ConfigPath = "$($PSScriptRoot)/OMServerFQDNs.txt";
        $OMServerFQDNs = Get-Content $ConfigPath;
        return [String[]]$OMServerFQDNs
    }
}

Class TASSystemFQDNs : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $TASConfigPath = "$($PSScriptRoot)/TASSystemFQDNs.txt";
        $TASSystemFQDNs = Get-Content $TASConfigPath;
        return [String[]]$TASSystemFQDNs
    }
}
function Export-TASAppUsageReport {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$TASFoundationName,

        [Parameter(Mandatory=$true)]
        [ValidateSet([TASSystemFQDNs])]
        [string]$TASSystemFQDN,

        [Parameter(Mandatory=$true)]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential
    )

    . "$($PSScriptRoot)/Get-TASAppUsage.ps1";

    $AppUsage = Get-TASAppUsage -TASSystemFQDN $TASSystemFQDN -OMServerFQDN $OMServerFQDN -OMCredential $OMCredential
    
    if ($AppUsage.count -gt 0) {
        $MonthlyReports = $AppUsage.monthly_reports;
        $Years = $MonthlyReports.year | Get-Unique | Sort-Object -Descending

        $FinalAppUsageObject = @();

        foreach ($Year in $Years) {
            $MonthlyReportsFilteredByYear = $MonthlyReports | Where-Object {$_.year -eq $Year}
            
            $FinalAppUsageObject += New-Object psobject -Property @{
                time_period = $Year;
                average_app_instances =  [math]::Round(($MonthlyReportsFilteredByYear.average_app_instances | Measure-Object -Average).Average,4);
                maximum_app_instances = ($MonthlyReportsFilteredByYear.maximum_app_instances | Measure-Object -Maximum).Maximum;
                app_instance_hours = [math]::Round(($MonthlyReportsFilteredByYear.app_instance_hours | Measure-Object -Sum).Sum,4);
            }

            foreach ($MonthlyReport in $MonthlyReportsFilteredByYear) {
                $FinalAppUsageObject += New-Object psobject -Property @{
                    time_period = "$($MonthlyReport.year)-$($MonthlyReport.month)";
                    average_app_instances = [math]::Round($MonthlyReport.average_app_instances,4);
                    maximum_app_instances = $MonthlyReport.maximum_app_instances;
                    app_instance_hours = [math]::Round($MonthlyReport.app_instance_hours,4);
                }
            }
        }
        
        $Timestamp = (Get-Date -format mmddyyhhMMss)
        $Folderpath = "~/Desktop/tas_appusage_reports/$($TASFoundationName)"
        if (-not (Test-Path -Path $Folderpath -PathType container)) {
            New-Item -Path $Folderpath -ItemType container -Force
        }
        $FinalAppUsageObject | Select-Object time_period,average_app_instances,maximum_app_instances,app_instance_hours | Export-Csv -Path "$($Folderpath)/app-usage-$(($Years | Measure-Object -Minimum).Minimum)_$(($Years | Measure-Object -Maximum).Maximum)_$($Timestamp).csv"
    }
    else {
        Write-Error -Message "No App Usages were Returned."
    }
    return $null;
}