Class OMServerFQDNs : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $ConfigPath = "$($PSScriptRoot)/OMServerFQDNs.txt";
        $OMServerFQDNs = Get-Content $ConfigPath;
        return [String[]]$OMServerFQDNs
    }
}
function Get-OMBearerToken {

    

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential
    )

    # Return Object
    $ReturnObject = $null;

    # REST API Path
    $APIPath = "/uaa/oauth/token";

    # Validate Credentials for Token
    if ($OMCredential -ne $null) {
        $RequestUserName = $OMCredential.UserName;
        $RequestPassword = [System.Web.HttpUtility]::UrlEncode((ConvertFrom-SecureString -AsPlainText -SecureString $OMCredential.Password));
    }

    $RequestURL = "https://$($OMServerFQDN)$($APIPath)";
    $RequestHeaders = @{"charset"="utf-8";"Accept"="application/json";};

    $RequestBodyObject = "grant_type=password&username=$($RequestUserName)&password=$($RequestPassword)";
    $OMID = New-Object System.Management.Automation.PSCredential ("opsman", (new-object System.Security.SecureString));

    $Request = Invoke-WebRequest $RequestURL -Method POST -Headers $RequestHeaders -Body $RequestBodyObject -Authentication Basic -Credential $OMID -SkipCertificateCheck;

    if ($null -ne $Request) {
        $RequestContent = $Request.content | ConvertFrom-Json -AsHashtable | ConvertTo-Json -Depth 100 | ConvertFrom-Json;
        if ($null -ne $RequestContent) {
            $ReturnObject = $RequestContent.access_token;
        }
        else {
            Write-Error "There was no Request Response Content";
        }
    }
    else {
        Write-Error "The Token Request Failed";
    }

    return $ReturnObject;
}
