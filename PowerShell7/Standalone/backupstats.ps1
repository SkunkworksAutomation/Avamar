<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.4
#>

$global:AuthObject = $null

function connect-restapi {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$Server
    )
    begin {
        # CHECK TO SEE IF OAUTH2 CREDS FILE EXISTS IF NOT CREATE ONE
        $exists = Test-Path -Path ".\oauth2.xml" -PathType Leaf
        if($exists) {
            $oauth2 = Import-CliXml ".\oauth2.xml"
        } else {
            $oauth2 = Get-Credential -Message "Please specify your oauth2 credentials."
            $oauth2 | Export-CliXml ".\oauth2.xml"
        }

        # CHECK TO SEE IF ADMIN CREDS FILE EXISTS IF NOT CREATE ONE
        $exists = Test-Path -Path ".\admin.xml" -PathType Leaf
        if($exists) {
            $admin = Import-CliXml ".\admin.xml"
        } else {
            $admin = Get-Credential -Message "Please specify your admin credentials."
            $admin | Export-CliXml ".\admin.xml"
        }

        # BASE64 ENCODE USERNAME AND PASSWORD AND CREATE THE REQUEST BODY
        $base64AuthInfo = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes(
                (
                    "{0}:{1}" -f $oauth2.username,
                    (ConvertFrom-SecureString -SecureString $oauth2.password -AsPlainText)
                )
            )
        )
        $body = @(
            "grant_type=password",
            "scope=write",
            "username=$($admin.username)",
            "password=$(ConvertFrom-SecureString -SecureString $admin.password -AsPlainText)"
        )
    }
    process {
        #AUTHENTICATE TO THE AVAMAR API 
        $auth = Invoke-RestMethod `
        -Uri "https://$($Server)/api/oauth/token" `
        -Method POST `
        -ContentType 'application/x-www-form-urlencoded' `
        -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} `
        -Body ($body -join '&')`
        -SkipCertificateCheck

        #BUILD THE AUTHOBJECT FOR SUBESEQUENT REST API CALLS
        $object = @{
            server ="https://$($Server)/api/v1"
            token= @{
                authorization="Bearer $($auth.access_token)"
            } #END TOKEN
        } # END

        # SET THE AUTHOBJECT VALUES
        $global:AuthObject = $object
        $global:AuthObject | Format-List
    }
}

function get-clients {
    [CmdletBinding()]
   param (
        [Parameter( Mandatory=$false)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [array]$Path
   )
   begin {}
   process {
        $Results = @()
        
        $Endpoint = "clients"
        $Join = ($Path -join '&') -replace '\s','%20' -replace '"','%22'
        $Filter = ($Filters -join '&') -replace '\s','%20' -replace '"','%22'

        if($Filters.length -eq 0) {
            $Uri = "$($Endpoint)?$($Join)"
        } else {
            $Uri = "$($Endpoint)?$($Join)&filter=$($Filter)"
        }
        
       # GET THE CLIENTS
       $Query = Invoke-RestMethod `
       -Uri "$($AuthObject.server)/$($Uri)&page=0" `
       -Method GET `
       -ContentType 'application/json' `
       -Headers ($AuthObject.token) `
       -SkipCertificateCheck
     
       # IF THE RESULTS ARE GREATER THAN 1 PAGE, GET ALL PAGED RESULTS
       if($Query.totalPages -gt 1) {
           for($i=0;$i -lt $Query.totalPages;$i++) {
               Write-Progress `
               -Activity "Processing pages..." `
               -Status "$($i+1) of $($Query.totalPages) - $([math]::round((($i/$Query.totalPages)*100),2))% " `
               -PercentComplete (($i/$Query.totalPages)*100)

               $Pages = Invoke-RestMethod `
               -Uri "$($AuthObject.server)/$($Uri)&page=$($i)" `
               -Method GET `
               -ContentType 'application/json' `
               -Headers ($AuthObject.token) `
               -SkipCertificateCheck

               $Results += $Pages.content
           } # END FOR
       } else {
           $Results = $Query.content
       }
       return $Results;
   } # END PROCESS
} # END FUNCTION

function get-statistics {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$Id
    )
    begin {}
    process {
                
        $Endpoint = "clients"
        $Uri = "$($Endpoint)/$($Id)/backup-statistics"
        
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/$($Uri)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        return $Query
    } # END PROCESS
} # END FUNCTION

# AVAMAR SERVER
$avamar = 'ave-01.vcorp.local'
# AVAMAR DOMAIN (vCenter)
$domain = "/vc-01.vcorp.local"

# RESULTS ARRAY
$results = @()

# CONNECT TO THE AVAMAR REST API
connect-restapi -Server $avamar

# FILTERS TO APPLY
$Filters = @(
    "clientType==VMACHINE"
)
# FIELDS TO RETURN
$Fileds = @(
    "id",
    "name",
    "domainFqdn",
    "clientType",
    "clientOS"
)
# URI PATH PARAMETERS
$Path = @(
    "domain=$($domain)",
    "recursive=true",
    "size=10",
    "fields=$($Fileds -join ',')"
)

$clients = get-clients -Filters $Filters -Path $Path

$clients | foreach-object {
    # GET THE BACKUP STATISTICS
    $stats = get-statistics -Id $_.id

    $object = [ordered]@{
        id = $_.Id
        name = $_.name
        domainFqdn = $_.domainFqdn
        clientType = $_.clientType
        clientOS = $_.clientOS
        totalBackups = $stats.totalBackups
        backupCount = $stats.backupCount
        failedBackupCount = $stats.failedBackupCount
        lastProtectedSize = $stats.lastProtectedSize
        totalBackupTime = $stats.totalBackupTime
        totalIncrementalSize = $stats.totalIncrementalSize
        lastBackupTime = $stats.lastBackupTime
        jobs = $stats.jobs
        backupPolicies = $stats.backupPolicies
        nextBackupTime = $stats.nextBackupTime
    }
    $results += (New-Object -TypeName pscustomobject -Property $object)
}
 # $results | format-list
 $results | Export-Csv ".\backup-statistics.csv" -NoTypeInformation