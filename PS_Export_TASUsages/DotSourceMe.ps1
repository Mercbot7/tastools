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