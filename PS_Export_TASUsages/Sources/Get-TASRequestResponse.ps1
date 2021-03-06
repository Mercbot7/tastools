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
function Get-TASRequestResponse {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ApiURI,
        
        [Parameter()]
        [string]$ApiSubDomain = "api",

        [Parameter()]
        [ValidateSet("GET","POST")]
        [string]$ApiMethod = "GET",

        [Parameter()]
        [switch]$FullBody,

        [Parameter(Mandatory=$true)]
        [ValidateSet([TASSystemFQDNs])]
        [string]$TASSystemFQDN,

        [Parameter(Mandatory=$true,ParameterSetName='GetToken')]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter(Mandatory=$true,ParameterSetName='GetToken')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential,

        [Parameter(Mandatory=$true,ParameterSetName='GivenToken')]
        [SecureString]$TASAdminBearerToken

    )

    . "$($PSScriptRoot)/Get-TASAdminBearerToken.ps1";

    # Return Object
    $ReturnObject = $null;

    if ($null -eq $TASAdminBearerToken) {
        $TASAdminBearerToken = Get-TASAdminBearerToken -TASSystemFQDN $TASSystemFQDN -OMServerFQDN $OMServerFQDN -OMCredential $OMCredential | ConvertTo-SecureString -AsPlainText -Force;
    }
    
    # validate Credentials
    if ($null -ne $TASAdminBearerToken) {

        $RequestURL = "https://$($ApiSubDomain).$($TASSystemFQDN)$($ApiURI)";
        $RequestHeaders = @{"Accept"="application/json";"charset"="utf-8";};

        $Request = Invoke-WebRequest $RequestURL -Method GET -Headers $RequestHeaders -Authentication Bearer -Token $TASAdminBearerToken;

        if ($null -ne $Request) {
            $RequestContent = $Request.content | ConvertFrom-Json;
            
            if ($null -ne $RequestContent) {
                if ($FullBody) {
                    $ReturnObject = $RequestContent;
                }
                else {
                    $ReturnObject = $RequestContent.resources;
                }
            }
            else {
                Write-Error "The Request Content has Nothing.";
            }
        }
        else {
            Write-Error "The Request returned Nothing.";
        }
    }
    else {
        Write-Error "We did not get TAS Admin Token!";
    }
    return $ReturnObject;
}