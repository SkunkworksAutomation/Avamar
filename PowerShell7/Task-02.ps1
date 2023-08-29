<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.avamar.psm1 -Force
$avamar = 'ave-01.vcorp.local'
$pagesize = 25
connect-restapi -Server $avamar

<#
   GET CLIENTS
#>

$query = get-clients -PageSize $pagesize

$query | format-list
