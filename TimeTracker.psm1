function get-open-connection
{
    $file = 'C:\Data\TimeTracker.accdb'
    if (Test-Path $file)
    {
        $result = New-Object System.Data.OleDb.OleDbConnection
        $result.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$file"
        $result.Open()
        $result
    } else 
    {
        throw [System.Exception] "DB file doesn't exist: $file"
    }
}

function get-command([System.Data.OleDb.OleDbConnection] $con, [string] $cmdText)
{
    $result = New-Object System.Data.OleDb.OleDbCommand
    $result.CommandText = $cmdText
    $result.Connection = $con
    $result
}

# Returns true if one (if $onlyone) or any (if not) uncommitted entry(ies) exist(s)
# If commented true, only if uncommitted entry has a comment.
function uncommitted-entry([bool] $onlyone, [bool] $commented = $False)
{
    $con = get-open-connection
    $cmd = get-command $con "SELECT 1 FROM Table1 where DateTimeOut Is Null$(if ($commented){' and Comment Is Not Null'})"

    #$reader = $cmd.ExecuteReader([System.Data.CommandBehavior.CloseConnection])  can't be done
    $reader = $cmd.ExecuteReader() #execute scalar doesn't seem to return anything.  It's not null, blank string, and debugger just shows nothing.
    # In PowerShell, the results of each statement are returned as output, even without a statement that contains the Return keyword
    $reader.Read() > $null
    if ($onlyone)
    {
        ($reader.HasRows) -and !($reader.Read())
    } else
    {
        $reader.HasRows # output
    }
    $con.Close() > $null
}

# Pre: uncommitted-entry returned true
# Returns time in, comment (if pass commented)
function get-uncommitted-details([bool] $commented)
{
    $con = get-open-connection
    $cmd = get-command $con "SELECT DateTimeIn, Comment FROM Table1 where DateTimeOut Is Null$(if ($commented){' and Comment Is Not Null'})"
    $reader = $cmd.ExecuteReader() #execute scalar doesn't seem to return anything.  It's not null, blank string, and debugger just shows nothing.
    # In PowerShell, the results of each statement are returned as output, even without a statement that contains the Return keyword
    $reader.Read() > $null
    # return hash table.  Array can have different types as well; would just be @($reader[0], $reader[1])
    @{TimeIn=$reader[0]; Comment=$reader[1]}
    $con.Close() > $null
}

function ClockIn([string] $comment)
{
    if (uncommitted-entry $False)
    {
        throw [System.Exception] "Uncommitted entry(ies).  Fix it."
    } else
    {
        $con = get-open-connection
        $now = Get-Date #[System.DateTime]::Now
        #Double quoted string expand variables and single quoted strings do not.
        if ($comment)
        {
            $cmd = get-command $con "INSERT INTO Table1 (DateTimeIn, Comment) values(#$now#, '$comment')"
        } else
        {
            $cmd = get-command $con "INSERT INTO Table1 (DateTimeIn) values(#$now#)"
        }
        $cmd.ExecuteNonQuery() > $null
        $con.Close()
        echo 'clocked in'
    }
}

# Pre: uncommitted-entry returned true
function get-uncommitted-hours([bool] $commented = $False)
{
    $details = get-uncommitted-details($commented) #Zote: you can't add .TimeIn to this; can't chain like that.
    $timein = $details.TimeIn
    $now = [DateTime]::Now
    $span = $now - [DateTime]$timein
    [Math]::Round($span.TotalHours, 2)
}

# ToDo: escape single ticks - blows up the query
function ClockOut([string] $comment)
{
    if (uncommitted-entry $True)
    {
        $now = [DateTime]::Now
        $uncommitedhours = get-uncommitted-hours
        $con = get-open-connection

        if ($comment)
        {
            $cmd = get-command $con "update Table1 set DateTimeOut = #$now#, Hours = $uncommitedhours, Comment = '$comment' where DateTimeOut Is Null"
        } else
        {
            $cmd = get-command $con "update Table1 set DateTimeOut = #$now#, Hours = $uncommitedhours where DateTimeOut Is Null"
        }
        $cmd.ExecuteNonQuery() > $null
        $con.Close()
        echo 'clocked out, yo.'
    } else
    {
        throw [System.Exception] "TimeOut: expected one uncommitted entry.  Go fix."
    }
}

# Returns past Sunday at midnight as DateTime
function sunday
{
    $start = [int][DateTime]::Now.DayOfWeek
    $target = 7
    $result = [DateTime]::Now
	if ($start -gt $target)
    {
		$result = $result.AddDays($target - $start)
    } else
    {
	    if ($start -lt $target)
        {
		    $result = $result.AddDays($target - $start - 7)
        } else
        {
		    $result = $result.AddDays(-7)
        }
    }
    $result.Date
}

# Returns hours, comments for tasks that are commented.
function ClockWeekCommented
{
    $con = get-open-connection
    $sunday = sunday
    $hours = 0
    $comments = ''
    $cmd = get-command $con "SELECT Hours, Comment FROM Table1 where DateTimeIn >= #$sunday# and Comment <> Null"
    $reader = $cmd.ExecuteReader()
    while ($reader.Read())
    {
        $hours = [Math]::Round($hours + $reader[0], 2)
        if ($comments -ne '')
        {
            $comments = "$comments | "
        }
        # OTHER strings can be concatenated directly, but this one must be wrapped.
        $comments = "$comments $($reader[1])"
    }
    $con.Close() > $null
    if (uncommitted-entry $True $True) # if uncommitted comment.  Note that you don't comma separate params.  Very strange.
    {
        $hours = $hours + (get-uncommitted-hours($True))
    }
    "$hours -> $comments"
}

# Returns hours for current week.
function ClockWeekHours
{
    $con = get-open-connection
    $sunday = sunday
    $cmd = get-command $con "select sum(Hours) from Table1 where DateTimeIn >= #$sunday#"
    $reader = $cmd.ExecuteReader()
    $reader.Read() > $null # has rows even when no records!
    $readerresult = $reader[0]
    $con.Close()
    if ($readerresult -is [System.DBNull])
    {
        $result = 0
    } else
    {
        $result = [double]$readerresult
        if (uncommitted-entry $False)
        {
            $uncommitedhours = get-uncommitted-hours
            $result = [Math]::Round($result + $uncommitedhours, 2)
        }
    }
    $result
}

# Returns last week's hours (the week prior to last Sunday)
function ClockLastWeekHours
{
    $con = get-open-connection
    $sunday = sunday
    $priorSunday = $sunday.AddDays(-7)
    $cmd = get-command $con "select sum(Hours) from Table1 where (DateTimeIn >= #$priorSunday#) and (DateTimeIn < #$sunday#)"
    $reader = $cmd.ExecuteReader()
    $reader.Read() > $null # has rows even when no records!
    $readerresult = $reader[0]
    $con.Close()
    if ($readerresult -is [System.DBNull])
    {
        $result = 0
    } else
    {
        $result = [double]$readerresult
    }
    $result
}

function ClockStatus
{
    if (uncommitted-entry $False)
    {
        $uncommitedDetails = get-uncommitted-details
        $timein = $uncommitedDetails.TimeIn
        $timeuncommitted = [DateTime]::Now - $timein
        $hours = [Math]::Round($timeuncommitted.TotalHours, 2)
        $timeinstr = $timein.ToShortTimeString()
        "Task with comment [$(if ($uncommitedDetails.Comment) {$uncommitedDetails.Comment})] in progress beginning $timeinstr with hours $hours"
    } else
    {
        "No tasks in progress"
    }
}

<#
    Tests (began with empty db).  You have to copy this to a ps1 file to debug.
    status
    week-hours - 0
    clock-in no comment
    attempt clock-in again
    status
    clock-out no comment
    check table
    status
    attempt clock-out
    clock-in with comment
    week-hours
    check table for above comment
    clock-out with comment
#>

Export-ModuleMember -function ClockIn
Export-ModuleMember -function ClockOut
Export-ModuleMember -function ClockWeekHours
Export-ModuleMember -function ClockLastWeekHours
Export-ModuleMember -function ClockStatus
Export-ModuleMember -Function ClockWeekCommented

<#
Set-Alias guh get-uncommitted-hours
Export-ModuleMember -function get-uncommitted-hours -Alias guh
#>

