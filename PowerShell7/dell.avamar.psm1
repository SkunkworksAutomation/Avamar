<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
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

function get-datadomains {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {

        # GET ATTACHED DATA DOMAIN SYSTEMS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/datadomains" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        return $Query.content;
    } # END PROCESS
} # END FUNCTION

function get-clients {
     [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {}
    process {
        $Results = @()

        # OMIT /MC_RETIRED AND /MC_SYSTEM DOMAINS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients?filter=domainFqdn!=/MC_RETIRED&filter=domainFqdn!=/MC_SYSTEM&recursive=true&size=$($PageSize)&page=0" `
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
                -Uri "$($AuthObject.server)/clients?filter=domainFqdn!=/MC_RETIRED&filter=domainFqdn!=/MC_SYSTEM&recursive=true&size=$($PageSize)&page=$($i)" `
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

function get-checkpoints {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {

        # GET ATTACHED DATA DOMAIN SYSTEMS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/server/checkpoints" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        return $Query
    } # END PROCESS
} # END FUNCTION

function get-systemevents {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {

        # GET ATTACHED DATA DOMAIN SYSTEMS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/events/merged-events" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        
        return $Query
    } # END PROCESS
} # END FUNCTION

function get-activities {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {

        $Results = @()

        # OMIT /MC_RETIRED AND /MC_SYSTEM DOMAINS
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/clients?filter=domainFqdn!=/MC_RETIRED&filter=domainFqdn!=/MC_SYSTEM&recursive=true&size=$($PageSize)&page=0" `
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
                -Uri "$($AuthObject.server)/clients?filter=domainFqdn!=/MC_RETIRED&filter=domainFqdn!=/MC_SYSTEM&recursive=true&size=$($PageSize)&page=$($i)" `
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