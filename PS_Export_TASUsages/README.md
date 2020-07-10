# Export TAS Usage Reports

## Description
This set of scripts and functions will assist you with exporting the App Usage Reports for Tanzu Application Service requested 
by VMware on a regulaar basis for licensing. You will Dot Source the main file containing all the functions after entering your 
respective FQDNs into the ".txt" files

### FileSystem:
```.
├── DotSourceMe.ps1
├── OMServerFQDNs.txt
├── Sources
│   ├── Export-TASAppUsageReport.ps1
│   ├── Get-OMBearerToken.ps1
│   ├── Get-TASAdminBearerToken.ps1
│   ├── Get-TASAdminCreds.ps1
│   ├── Get-TASAppUsage.ps1
│   ├── Get-TASRequestResponse.ps1
│   └── Load-Cmdlets.ps1
└── TASSystemFQDNs.txt
```

### How to:
1. Set the Contents of the appropriate FQDN Text Files with your Operations Manager and TAS System FQDNs.
2. Open Powershell Session
3. cd to the directory of this tool *PS_Export_TASUsages*
4. Dot Source the DotSourceMe.ps1
> . ./DotSourceMe.ps1
5. Create OpsMan Credential Object
>  $OMCredential = Get-Credential

(enter the ops manager admin username and password) *this acount needs to be able to read the creds in the TAS tile*

6. Run the CMDlet to export the report.

### Help
- **Export-TASAppUsageReport**
  - **-TASFoundationName** [*string*] label used for naming the folder to place the report in. *If using on multiple foundations use unique names for each.*
  - **-TASSystemFQDN** [*string*] FQDN of TAS System. Validated against the entries in the TASSystemFQDNs.txt file.
  - **-OMServerFQDN** [*string*] FQDN of the Operations Manager Appliance
  - **-OMCredential** [*credential*] Credential Object of an Operations Manager Account with permissions to pull the TAS admin Credential.

**Example:**
> Export-TASAppUsageReport -TASFoundationName "lab" -TASSystemFQDN system.pcf.domain.corp -OMServerFQDN OMServerFQDN.domain.corp -OMCredential $OMCredential
