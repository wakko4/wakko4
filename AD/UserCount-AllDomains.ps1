# Gell User count for multiple domains  
$VerbosePreference = "Continue" 
Write-Host "Select csv file with Domains to import:" -f Green -b red

if(!$FileBrowser) { # If no file in memory open dialog windows to select 
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
       InitialDirectory = $PSScriptRoot
       Title = "Select CSV file with domains"
       Filter = 'CSV (*.csv)|*.csv' 
    }
    $null = $FileBrowser.ShowDialog()
}
#Export path
$path = (Get-Item $FileBrowser.FileName).DirectoryName 
Write-Host "`nFiles will be exported to....: $path" -f Yellow

$date = Get-Date -Format "yyyy-MM-dd-HHmm" 
$pwdset = (Get-Date).AddMonths(-3).ToFileTime()  # Pwd set last 3 months
  
$sw = new-object system.diagnostics.stopwatch
$sw.Start()

Start-Transcript -Path "$path\UsersCounts-Last3mnth-$date.txt" -Verbose

Write-Verbose "`n`nStarting $($myinvocation.mycommand)" 
Write-Verbose "Running as $($env:USERDOMAIN)\$($env:USERNAME) on $($env:Computername)" 
Write-Verbose "Using PowerShell version $($psversiontable.PSVersion)" 
Write-Verbose "Using ActiveDirectory module $((Get-Module ActiveDirectory).version)" 

Function Get-UsersCount {

    [cmdletbinding(DefaultParameterSetName = "All")]
    Param(
        [parameter(ValueFromPipeline, HelpMessage = "Specify the name of a specific Domain name")]
        [ValidateNotNullOrEmpty()]
        [string]$Domain

    )

    Begin {
            Write-Verbose "Using these bound parameters"  
            $PSBoundParameters | Out-String | Write-Verbose 

            $PSDefaultParameterValues["Get-AD*:Server"] = $Domain
            $size = $null ; $addomain = $null
    }
    Process {
        
        # Check first if Domain is reachable 
        try { $addomain = Get-ADDomain -ErrorAction SilentlyContinue
               Write-Host "Domain $domain connected sucessfuly" -f Green 
            }
        catch { Write-Host "Cannot connect to domain $domain " -f Green    }

        if($addomain){

            $users = Get-ADObject -LDAPFilter "(&(sAMAccountType=805306368)(!userAccountControl:1.2.840.113556.1.4.803:=2)(!userAccountControl:1.2.840.113556.1.4.803:=65536)(pwdLastSet>=$pwdset))" -Properties * -ResultSetSize $size | select samaccountnam*,Userprincipal*,GivenName,sn,UserAccountControl,mail

        }
    } # End of Process 
    End {
        Write-Verbose "Ending $($myinvocation.mycommand) on $Domain"
        if($addomain){ Return $users }
    } #end
}

$Table = [System.Collections.ArrayList]@()$UserCount = [System.Collections.ArrayList]@()
$domains = Import-Csv $FileBrowser.FileName 

foreach($domain in $domains.Domain){
    $temp = Get-UsersCount -Domain $domain| select @{n='Domain';E={$domain}},* 
    $Table += $temp
    $UserCount += [pscustomobject]@{ Domain = $domain ; Users = $temp.count }
}

$UserCount |  Export-Csv "$path\UsersCounts.csv" -NoTypeInformation
$Table |  Export-Csv "$path\UsersData.csv" -NoTypeInformation
$Table = $null

$sw.Stop()
Write-Host ($sw.Elapsed).Hours "Hour(s)" ($sw.Elapsed).Minutes "Minute(s) Elapsed:"  -f Cyan
Stop-Transcript
