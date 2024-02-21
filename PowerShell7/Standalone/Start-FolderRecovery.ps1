[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Number
    )
<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.4.1
#>

### DO NOT EDIT BELOW THIS LINE ###
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

function get-client {
    [CmdletBinding()]
    param (
         [Parameter( Mandatory=$true)]
        [string]$Domain,
        [Parameter( Mandatory=$true)]
        [bool]$Recursive,
        [Parameter( Mandatory=$true)]
        [string]$Client
    )
    begin {}
    process {

        $Results = @()
    
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients?domain=$($Domain)&recursive=$($Recursive)&page=0&filter=name==$($Client)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        $Results = $Query.content
      

        return $Results;
    } # END PROCESS
} # END FUNCTION

function get-backups {
    [CmdletBinding()]
    param (
         [Parameter( Mandatory=$true)]
        [string]$Cid,
        [Parameter( Mandatory=$true)]
        [string]$Date,
        [Parameter( Mandatory=$true)]
        [int]$Plugin
    )
    begin {}
    process {

        $Results = @()
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients/$($Cid)/backups?before=$($Date)T23:59:59.999Z&after=$($Date)T00:00:00.000Z&includeRemote=true&page=0&size=1&filter=pluginNumber==$($Plugin)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        $Results = $Query.content
      

        return $Results;
    }
}
function new-filelevelrecovery {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$Cid,
        [Parameter( Mandatory=$true)]
        [int]$Label,
        [object]$Body
    )
    begin {}
    process {
        
        $Action = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients/$($Cid)/backups/$($Label)/restore?destId=" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | ConvertTo-Json -Depth 10) `
        -SkipCertificateCheck

        return $Action;
    }
}

<#
    WORKFLOW
#>
$jobs = @()
$exists = Test-Path -Path ".\recovery$($Number).json" -PathType Leaf
if($exists){
    # RECOVERY CONFIGURATION INFORMATION
    $config = Get-Content ".\recovery$($Number).json" | convertfrom-json -Depth 10
    
    # SOURCE CLIENT INFORMATION
    $source = $config.source

    # ACTIVITIES
    $activities = $config.activities

} else {
    throw "[ERROR]: .\recovery$($Number).json does not exist in the script directory"
}

# CONNECT TO THE REST API
connect-restapi -Server $config.avamar

# QUERY FOR THE SOURCE CLIENT
$c1 = get-client -Domain $source.domain -Recursive $false -Client $source.client
$c1 | Select-Object name,id,domainFqdn


$activities | ForEach-Object {

    # GET THE BACKUPS FOR THIS ACTIVITY
    $c1b = @()
    foreach($date in $_.dates) {
        $c1b = get-backups -Cid $c1.id -Date $date -Plugin $source.plugin

        if($c1b.length -gt 0) {
            # QUERY FOR THE TARGET CLIENT
            $c2 = get-client -Domain $_.domain -Recursive $false -Client $_.target 
            $c2 | Select-Object name,id,domainFqdn
            
            $year = $date -split '-' | Select-Object -First 1

           if($c2.length -gt 0) {
               # DEFINE THE REQUEST BODY
               $body = [ordered]@{
                   encryption = "HIGH"
                   overwirttenFlags = [ordered]@{
                       "existing-file-overwrite-option"= "never"
                       "ddr-encrypt-strength"= "default"
                       "verbose"= "0"
                       "informationals"= "2"
                       "statistics"= $false
                       "debug"= $false
                       "run-at-start-exit"= $true
                       "run-at-end-exit"= $true
                       "checkcache"= $false
                       "repaircache"= $false
                       "rebuildcache"= $false
                       "no-recursion"= $false
                       "preservepaths"= $false
                       "allnodes"= $false
                       "restore-destination"= "single"
                   }
                   removeFlags=@()
                   pluginNumber=$_.plugin
                   destinationCid=$c2.id
                   restoreTargets = @(
                   )
               }
               foreach($folder in $_.folders) {
                   $item = [ordered]@{
                       snapTarget= [ordered]@{
                           pluginNumber=$_.plugin
                           name= "$($folder.name)"
                           isFile= $false
                           recordId= ""
                       }
                       saveAs="$($_.saveas)/$($year)/$($date)/"
                   }
                   $body.restoreTargets += $item
               }
   
               # $body | ConvertTo-Json -Depth 10
               # INVOKE THE FLR
               $job = new-filelevelrecovery -Cid $c1.id -Label $c1b.labelNumber -Body $body
               $jobs += $job
               $job
               
           } else {
               Write-Host "[WARNING]: No target client found with name: $($_.target) in $($_.domain)" -ForegroundColor Yellow
           }
       } else {
           Write-Host "[WARNING]: No backups found for client id: $($c1.id) on $($_.date)" -ForegroundColor Yellow
       }
   } # END ACTIVITIES

}

# $jobs | Out-File ".\activities$($Number).txt"