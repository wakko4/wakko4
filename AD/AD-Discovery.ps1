#########################
###   AD Discovery  #####
###                 #####
#########################

## Import list of domains and do discovery by domain [header - domain]

$path = "$env:USERPROFILE\Documents"
Write-Host "Make sure the folder on the path that you chose exist. Hit Enter to Continue " -ForegroundColor Yellow -BackgroundColor Red
Pause
$size = $null # set to 100 to test whole script first

Import-Csv "$path\Domains.csv" | ForEach-Object {

$domain = $_.Domain 
$file = $domain.Replace('.','-') + "-AD-Discovery"

$sw = new-object system.diagnostics.stopwatch
$sw.Start()
Start-Transcript -Path "$path\$file-PS.txt"


#AD Forest General Infromation
write-output "##--| AD FOREST INFORMATION |--##"
Get-ADForest -Server $domain

#AD Domain General Infromation
write-output "##--| AD DOMAIN INFORMATION |--##"
$AD = Get-ADDomain -Server $domain
$AD

#AD Domain Controllers (Name Only)
Write-Host "##--| AD DOMAIN CONTROLLERS |--##`n"
# Write-Host "##--| TOTAL DOMAIN CONTROLLERS |--##"
$AD.ReplicaDirectoryServers
Write-Host "`nTOTAL : " $AD.ReplicaDirectoryServers.Count


#AD FSMO Holders
write-output "##--| AD DOMAIN FSMO |--##"
netdom query fsmo

$roles = @('InfrastructureMaster','RIDMaster','PDCEmulator')
$roles | %{ Write-Host ("{0} {1:-150} {2}" -f ($_,':',$AD.$_)) -f Green} 

#AD Domain UPN Suffixes
write-output "##--| AD DOMAIN UPN SUFFIXES |--##"
Get-Adforest -Server $domain | select UPNSuffixes -ExpandProperty UPNSuffixes

#AD Domain Controller Details
write-output "##--| AD DOMAIN CONTROLLER DETAILS |--##"
Get-ADDomainController -Server $domain | FL `
	Enabled, `
    Name, `
    ServerObjectGuid, `
    Forest, `    
    Domain, `
    HostName, `
    OperatingSystem, `
    OperatingSystemHotfix, `
    OperatingSystemServicePack, `
    OperatingSystemVersion, `
    IPv4Address, `
    IPv6Address, `
    IsGlobalCatalog, `
    IsReadOnly, `
    OperationMasterRoles, `
    Site, `
    DefaultPartition, `
    ComputerObjectDN, `
    ServerObjectDN, `
    NTDSSettingsObjectDN, `
    Partitions, `
    LdapPort, `
    SslPort

#AD Trusts
Write-Output "##--| AD TRUSTS |--##"
Get-ADTrust -Server $domain -Filter { Target -like '*adxrt.com' } | select Name,Source,Target,Direction,ForestTransitive,IntraF*,SIDFil*,TrustType | ft

#Domain Controller Replication Summary
write-output "##--| Domain Controller Replication Summary |--##"
repadmin.exe /replsummary 


#AD OU Structure
#For some reason when testing only pulling "CREATED" OUs
$dn = (Get-ADDomain -Server $domain).DistinguishedName

write-output "##--| AD OU STRUCTURE |--##"
function Recurse-OU ([string]$dn, $level = 1)
{
    if ($level -eq 1) { $dn }
    Get-ADOrganizationalUnit -Server $domain -filter * -SearchBase $dn -SearchScope OneLevel -Properties CanonicalName -ResultSetSize 10| 
        Sort-Object DistinguishedName | 
        ForEach-Object { 
            $components = ($_.distinguishedname).split(',')
            $cn = $_.CanonicalName
            "$('--' * $level) $($components[0])"
            Recurse-OU -dn $_.distinguishedname -level ($level+1)
        }
}

Recurse-OU -dn $dn

#AD USERS (List All Users and Sort by Name)
write-output "##--| AD USERS, NAME ONLY |--##"
$users = Get-ADUser -Server $domain -LDAPFilter $ldap_filter -ResultSetSize $size -Properties * | Select-Object Name,UserPrincipalName,utc-com-1987-LDAP-UserType | Sort-Object Name 
$users | ft -AutoSize

#AD USERS (Export all User Details to CSV)
write-output "##--| AD USERS, ALL DETAILS TO CSV |--##"
# Get-ADUser -Server $domain -Filter * -Properties * | select CanonicalName,CN,Created,Description,DisplayName,DistinguishedName,EmailAddress,Enabled,GivenName,isDeleted,mail,Name,SamAccountName,sn,Surname,Title,UserPrincipalName,PasswordNeverExpires | Export-Csv "$path\$file-Users.csv"
$users | select CanonicalName,CN,Created,Description,DisplayName,DistinguishedName,EmailAddress,Enabled,GivenName,isDeleted,mail,Name,SamAccountName,sn,Surname,Title,UserPrincipalName,PasswordNeverExpires | Export-Csv "$path\$file-Users.csv" -NoTypeInformation

#AD GROUPS (List All Users and Sort by Name)
write-output "##--| AD USERS, NAME ONLY |--##"
$groups = Get-ADGroup -Server $domain -Filter * -ResultSetSize $size -Properties * | Select-Object SamAccountName | Sort-Object SamAccountName 
$groups | ft -AutoSize

#AD GROUPS (Export all User Details to CSV)
Write-Output "##--| AD USERS, ALL DETAILS TO CSV |--##"
# Get-ADGroup -Server $domain -Filter * -Properties * | select CanonicalName,CN,Created,Description,DisplayName,DistinguishedName,GroupCategory,GroupScope,isDeleted,Name,SamAccountName,whenChanged,whenCreated | Export-Csv "$path\$file-Groups.csv"
$groups | select CanonicalName,CN,Created,Description,DisplayName,DistinguishedName,GroupCategory,GroupScope,isDeleted,Name,SamAccountName,whenChanged,whenCreated | Export-Csv "$path\$file-Groups.csv" -NoTypeInformation

#AD COMPUTERS (Export all Computers Details to CSV)
Write-Output "##--| AD COMPUTERS, ALL DETAILS TO CSV |--##"
# Get-ADComputer -Server $domain -Filter * -Properties * -ResultSetSize $size | select Name,Enabled,OperatingSystem,OperatingSystemHotfix,OperatingSystemServicePack,OperatingSystemVersion,PasswordNeverExpires,SamAccountName,UserPrincipalName,whenChanged,whenCreated| Export-Csv "$path\$file-Computers.csv"
$pcs = Get-ADComputer -Server $domain -Filter * -Properties * -ResultSetSize $size | select Name,Enabled,OperatingSystem,OperatingSystemHotfix,OperatingSystemServicePack,OperatingSystemVersion,PasswordNeverExpires,SamAccountName,UserPrincipalName,whenChanged,whenCreated

Write-Output "##--| WINDOWS COMPUTERS |--##"
$pcs | Export-Csv "$path\$file-Computers.csv" -NoTypeInformation

Stop-Transcript

}

$sw.Stop()
#$sw.Elapsed
Write-Host "Hour(s):" ($sw.Elapsed).Hours "Min(s):" ($sw.Elapsed).Minutes "Sec(s):" ($sw.Elapsed).Seconds "Elapsed" -f Cyan
