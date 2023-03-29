<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.avamar.psm1 -Force
$avamar = 'ave-02.vcorp.local'

connect-restapi -Server $avamar

<#
   GET CLIENTS
#>

$query = get-checkpoints

# DISPLAY VALID AVAMAR CHECKPOINTS
$query | where-object {$_.hfscheckValidCheck -eq $true } | format-list


# DISPLAY INVALID AVAMAR CHECKPOINTS
$query | where-object {$_.hfscheckValidCheck -eq $false } | format-list