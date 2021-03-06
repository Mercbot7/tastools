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
function Get-TASAdminBearerToken {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateSet([TASSystemFQDNs])]
        [string]$TASSystemFQDN,

        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential
    )


    . "$($PSScriptRoot)/Get-TASAdminCreds.ps1";

    # Return Object
    $ReturnObject = $null;

    ## REST API Request Path
    $APIPath = "/oauth/token";

    if ($null -eq $OMCredential)  {
        $OMCredential = Get-Credential -Message "Please Enter the Ops Manager Admin Credential";
    }

    $TASAdminCreds = Get-TASAdminCreds -OMServerFQDN $OMServerFQDN -OMCredential $OMCredential;

    ## Validate Credentials
    if ($null -ne $TASAdminCreds) {
        $RequestUserName = $TASAdminCreds.UserName;
        $RequestPassword = [System.Web.HttpUtility]::UrlEncode((ConvertFrom-SecureString -AsPlainText -SecureString $TASAdminCreds.Password));
    
        $RequestURL = "https://login.$($TASSystemFQDN)$($APIPath)";
        $RequestHeaders = @{"Accept"="application/json";"charset"="utf-8";};

        $RequestBodyObject = "grant_type=password&username=$($RequestUserName)&password=$($RequestPassword)";
        $TASCred = New-Object System.Management.Automation.PSCredential ("cf", (new-object System.Security.SecureString));

        $Request = Invoke-WebRequest $RequestURL -Method POST -Headers $RequestHeaders -Body $RequestBodyObject -Authentication Basic -Credential $TASCred;

        if ($null -ne $Request) {
            $RequestContent = $Request.content | ConvertFrom-Json;
            if ($null -ne $RequestContent) {
                $ReturnObject =  $RequestContent.access_token;
            }
            else {
                Write-Error "The Requst Content is null."
            }
        }
        else {
            Write-Error "The request returned Nothing."
        }
    }
    else {
        Write-Error "We did not get TAS Admin Creds!"
    }
    return $ReturnObject;
}

