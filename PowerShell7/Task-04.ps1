<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.avamar.psm1 -Force
$avamar = 'ave-01.vcorp.local'

connect-restapi -Server $avamar

<#
   GET MERGED SYSTEM EVENTS
#>

$query = get-systemevents

# DISPLAY MERGED SYSTEM EVENTS
$query | format-list
