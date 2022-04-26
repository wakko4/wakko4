$domain = 'yourdomain.com' 

$PSDefaultParameterValues["Get-AD*:Server"] = $domain
Write-Verbose "`nUsing these bound parameters"
$PSDefaultParameterValues | Out-String | Write-Verbose

write-host "##--| AD DOMAIN CONTROLLERS |--##" -f Yellow

Get-ADForest  
$ado = Get-ADDomain 

$ADForestconfigurationNamingContext = (Get-ADRootDSE).configurationNamingContext 

$DirectoryServicesConfigPartition = Get-ADObject -Identity “CN=Directory Service,CN=Windows NT,CN=Services,$ADForestconfigurationNamingContext” -Partition $ADForestconfigurationNamingContext -Properties *
$TombstoneLifetime = $DirectoryServicesConfigPartition.tombstoneLifetime

Write-Host $domain -f Green
$dc = Get-ADDomainController 

    $info = [pscustomobject]@{

        Domain = $ado.Domain
        PDC = $ado.PDCEmulator
        RID = $ado.RIDMaster
        Infra = $ado.InfrastructureMaster
        FQDN = $dc.HostName
        IP = $dc.IPv4Address
        Forest = $dc.Forest
        Site = $dc.Site
        TombstoneLife = $TombstoneLifetime

    }

$info | Export-Csv $path\dcinfo.csv -NoTypeInformation
