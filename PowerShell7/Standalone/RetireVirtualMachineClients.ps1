[CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [switch]$Decommission
    )
# PARAMS
$avamar = 'ave-01.vcorp.local'
$vcenter = 'vc-01.vcorp.local'
$search = "decom_"

<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases

    DO NOT MODIFY BELOW THIS LINE
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
        [Parameter( Mandatory=$true)]
        [string]$Search,
        [Parameter( Mandatory=$true)]
        [string]$Domain,
        [Parameter( Mandatory=$true)]
        [bool]$Recursive
    )
    begin {}
    process {

        $Results = @()
        
        # OMIT /MC_RETIRED AND /MC_SYSTEM DOMAINS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients?domain=$($Domain)&recursive=$($Recursive)&filter=name==$($Search)*" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        $Results = $Query.content
      

        return $Results;
    } # END PROCESS
} # END FUNCTION

function set-client {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$Id
    )
    begin {}
    process {
        # BUILD THE REQUEST BODY
        $body = [ordered]@{
            localBackupExpirationTime = $null
            remoteBackupExpirationTime = $null
            forceRetire = $false
            parentCid = $null
        }
        # RETIRE THE CLIENT
        $Action = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients/$($Id)/retire" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($body | ConvertTo-Json -Depth 10) `
        -SkipCertificateCheck

        return $Action;

    } # END PROCESS
} # END FUNCTION

# WORKFLOW
# 1.) Connect to the Avamar REST API
connect-restapi -Server $avamar

# 2.) Get the clients to decommission
$clients = get-clients -Search $search -Domain "/$($vcenter)" -Recursive $true
$clients | Select-Object id,name | Format-Table -AutoSize

if($clients.length -gt 0){
    # DECOMMISSION, TRUE
    if($Decommission) {
        # 3.) Iterate of the clients
        foreach($client in $clients){
            Write-Host "[$($avamar)]: Retiring client id :$($client.id), client: $($client.name)" -ForegroundColor Yellow
            # 4. Retire the client
            set-client -Id $client.id | Out-Null
        }
    }
} else {
    Write-Host "[$($avamar)]: No vm names found to decommission begining with: $($search)" -ForegroundColor Yellow
}