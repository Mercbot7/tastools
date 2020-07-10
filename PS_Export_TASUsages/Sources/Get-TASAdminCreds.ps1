Class OMServerFQDNs : System.Management.Automation.IValidateSetValuesGenerator {
    [String[]] GetValidValues() {
        $ConfigPath = "$($PSScriptRoot)/OMServerFQDNs.txt";
        $OMServerFQDNs = Get-Content $ConfigPath;
        return [String[]]$OMServerFQDNs
    }
}
function Get-TASAdminCreds {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateSet([OMServerFQDNs])]
        [string]$OMServerFQDN,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]$OMCredential,

        [Parameter()]
        [System.Security.SecureString]$OMBearerToken = $null
    )

    # Script Sourcing
    . "$($PSScriptRoot)/Get-OMBearerToken.ps1";

    # Return Object
    $ReturnObject = $null;

    ### Get OM Bearer Token
    if ([string]::IsNullOrEmpty($OMBearerToken)) {
        if ($null -eq $OMCredential)  {
            $OMCredential = Get-Credential -Message "Please Enter the Ops Manager Admin Credential"
        }
        $OMBearerToken = Get-OMBearerToken -OMServerFQDN $OMServerFQDN -OMCredential $OMCredential | ConvertTo-SecureString -AsPlainText -Force;
    }

    if ( -not ([string]::IsNullOrEmpty($OMBearerToken))) {

        $RequestHeaders = @{"Accept"="application/json";"charset"="utf-8";};

        ## REST API Request Path
        $APIPathProducts = "/api/v0/deployed/products";

        $ProductsRequestURL = "https://$($OMServerFQDN)$($APIPathProducts)"
            
        $ProductsRequest = Invoke-WebRequest $ProductsRequestURL -Method GET -Headers $RequestHeaders -Authentication Bearer -Token $OMBearerToken
        $ProductsRequestContent = $ProductsRequest.content | ConvertFrom-Json;
        $TASProduct = $ProductsRequestContent | Where-Object {$_.type -eq "cf"}

        $AdminCredReferenceString = ".uaa.admin_credentials";
        $APIPathProductCreds = "/api/v0/deployed/products/$($TASProduct.guid)/credentials"
        $ProductCredsRequestURL = "https://$($OMServerFQDN)$($APIPathProductCreds)"
        $ProductCredsRequest = Invoke-WebRequest $ProductCredsRequestURL -Method GET -Headers $RequestHeaders -Authentication Bearer -Token $OMBearerToken
        $ProductCredsRequestContent = $ProductCredsRequest.content | ConvertFrom-Json;
        
        if ($ProductCredsRequestContent.credentials -contains $AdminCredReferenceString) {
            $APIPathProductAdminCred = "/api/v0/deployed/products/$($TASProduct.guid)/credentials/$($AdminCredReferenceString)";
            $AdminCredRequestURL = "https://$($OMServerFQDN)$($APIPathProductAdminCred)";
            $AdminCredRequest = Invoke-WebRequest $AdminCredRequestURL -Method GET -Headers $RequestHeaders -Authentication Bearer -Token $OMBearerToken;
            $AdminCredRequestContent = $AdminCredRequest.content | ConvertFrom-Json;
            $AdminCredRequestContentValue = $AdminCredRequestContent.credential.value;
            $AdminCredSecPassword = ConvertTo-SecureString $AdminCredRequestContentValue.password -AsPlainText -Force
            $AdminCred = New-Object System.Management.Automation.PSCredential ("$($AdminCredRequestContentValue.identity)", $AdminCredSecPassword)
        }
        else {

        }

        if ($null -ne $AdminCred) {
            $ReturnObject =  $AdminCred;
        }
        else {
            Write-Error "The Admin Cred for $($OMServerFQDN) was not found."
        }
    }
    return $ReturnObject;
}