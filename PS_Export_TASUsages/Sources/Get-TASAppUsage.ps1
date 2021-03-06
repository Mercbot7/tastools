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
function Get-TASAppUsage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateSet([TASSystemFQDNs])]
        [string]$TASSystemFQDN,

        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter(Mandatory=$true,ParameterSetName='GetToken')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential,

        [Parameter(Mandatory=$true,ParameterSetName='GivenToken')]
        [SecureString]$TASAdminBearerToken
    )
 
    . "$($PSScriptRoot)/Get-TASAdminBearerToken.ps1";
    . "$($PSScriptRoot)/Get-TASRequestResponse.ps1";

    # Return Object
    $ReturnObject = $null;

    # REST API Request Path
    $ApiSubDomain = "app-usage"

    # REST API Request Path
    $ApiURI = "/system_report/app_usages";

    if ($null -eq $TASAdminBearerToken) {
        $TASAdminBearerToken = Get-TASAdminBearerToken -TASSystemFQDN $TASSystemFQDN -OMServerFQDN $OMServerFQDN -OMCredential $OMCredential | ConvertTo-SecureString -AsPlainText -Force;
    }

    ## validate Credentials and parse out the info for the token Request
    if ($null -ne $TASAdminBearerToken) {

        $TASAppUsages = Get-TASRequestResponse -ApiSubDomain $ApiSubDomain -ApiURI $ApiURI -TASSystemFQDN $TASSystemFQDN -TASAdminBearerToken $TASAdminBearerToken -FullBody;

        if ($null -ne $TASAppUsages) {
            $ReturnObject = $TASAppUsages;
        }
        else {
            Write-Host "Something Went wrong with the Request! We did not get anything back!"
        }
    }
    else {
        Write-Error "We did not get TAS Admin Token!"
    }

    return $ReturnObject;
}