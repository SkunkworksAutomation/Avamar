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
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f `
            $oauth2.username,(ConvertFrom-SecureString -SecureString $oauth2.password -AsPlainText))))
        $body = "grant_type=password&scope=write&username=$($admin.username)&password=$(ConvertFrom-SecureString -SecureString $admin.password -AsPlainText)" 
    }
    process {
        #AUTHENTICATE TO THE AVAMAR API 
        $auth = Invoke-RestMethod `
        -Uri "https://$($Server)/api/oauth/token" `
        -Method POST `
        -ContentType 'application/x-www-form-urlencoded' `
        -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} `
        -Body $body `
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