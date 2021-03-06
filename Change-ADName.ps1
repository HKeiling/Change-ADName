# Function that creates a custom object so I can easily export log data to a csv
function New-CustomOb {
    
    Param(
    [String]$Result,
    [String]$Function,
    [String]$User,
    [String]$Subject
    )
    
    $date = get-date -format s

    $CustomOb = new-object psobject
    $CustomOb | add-member -type NoteProperty -name Date -value "$Date"
    $CustomOb | add-member -type NoteProperty -Name User -Value "$User"
    $CustomOb | add-member -type NoteProperty -Name Function -Value "$Function"
    $CustomOb | add-member -type NoteProperty -Name Subject -Value "$Subject"
    $CustomOb | add-member -type NoteProperty -Name Result -Value "$Result"

    $CustomOb
}


#region All important variables here
# Location of CSV with user ID and preferred name (csv headers: "NetworkID","PreferredFirstName")
$CSV = import-csv "C:\scripts\CSV.csv"

# Location of the log file
$MasterLog = "C:\scripts\NameChangeLog.csv"

# Which domain controller to use
$DC = "domainController.domain.local"
#endregion

# Do this for each user in the csv file
foreach ($User in $CSV) {
    
    #region Variables
    $UserSAN = $User.NetworkID
    $UserPreferred = $User.PreferredFirstName
    write-host "$UserSAN"
    # Create empty array
    $MasterLogArray = @()
    #endregion
    $error.clear()

    # Try finding user in AD. If an error occurs, log it and move to the next entry in foreach loop
    TRY { $ADUser = get-aduser -Identity $UserSAN -Properties displayname -server $DC }
    Catch 
        {
        $MasterLogArray += New-CustomOB -Function "Get-ADUser" -User $($UserSAN) -Subject $($UserPreferred) -Result "$Error"
        $MasterLogArray | export-csv $MasterLog -NoTypeInformation -Append
        return
        }

    #region Variables for AD Account
    $AD_Lastname = $ADUser.Surname
    $AD_Displayname = "$AD_Lastname, $UserPreferred"
    $AD_Name = "$AD_Lastname, $UserPreferred"
    $AD_DN = $ADUser.DistinguishedName
    #endregion
    
    $error.clear()
    # Change users first name and their "display name" to match
    TRY { Set-ADUser -Identity $UserSAN -GivenName $UserPreferred -DisplayName $AD_DisplayName -server $DC }
    Catch 
        { 
        $MasterLogArray += New-CustomOB -Function "Set-ADUser" -User $($UserSAN) -Subject $($UserPreferred) -Result "$Error"
        }

    If (!$error) 
        { 
        $MasterLogArray += New-CustomOB -Function "Set-ADUser" -User $($UserSAN) -Subject $($UserPreferred) -Result "Success"
        }

    $error.clear()
    # Change users "name" on the actual AD object
    TRY { Rename-ADObject -Identity $AD_DN -newname $AD_Name -server $DC }
    Catch 
        { 
        $MasterLogArray += New-CustomOB -Function "Rename-ADObject" -User $($UserSAN) -Subject $($AD_Name) -Result "$Error"
        }

    If (!$error) 
        { 
        $MasterLogArray += New-CustomOB -Function "Rename-ADObject" -User $($UserSAN) -Subject $($AD_Name) -Result "Success"
        }

    # Export data to our log
    $MasterLogArray | export-csv $MasterLog -NoTypeInformation -Append

}
