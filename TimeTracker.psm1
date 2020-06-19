#All time herein is accounted as localtime, not UTC.

function load-sqllite-type
{
  # ToDo: see README
  try
  {
    # no way to check for existing type that I can find.  Calling this function because it never hurts; we have no long-lived connections herein.
    # https://stackoverflow.com/questions/8511901/system-data-sqlite-close-not-releasing-database-file
    [System.Data.SQLite.SQLiteConnection]::ClearAllPools() > $null
  }
  catch
  {
    Add-Type -Path 'C:\source\powershell-time-tracker\System.Data.SQLite.dll'
  }
}

function get-open-connection
{
  $DB_Path = 'C:\Data\TimeTracker.db'
  if (Test-Path $DB_Path)
  {
    load-sqllite-type
    # You can't load this sucker; it's not a CLR assembly.  If windows, it must live in same dir as the CLR assembly (at least for this script it does).
    #Add-Type -Path "$nugetpath\runtimes\win-x64\native\netstandard2.0\SQLite.Interop.dll"
    $result = New-Object System.Data.SQLite.SQLiteConnection -ArgumentList "Data Source=$DB_Path;Version=3;"
    $result.Open() > $null
    $result
  } else 
  {
    throw [System.Exception] "DB file doesn't exist: $DB_Path"
  }
}

function close-connection([System.Data.SQLite.SQLiteConnection] $con, [System.Data.SQLite.SQLiteCommand] $cmd, [System.Data.SQLite.SQLiteDataReader] $reader = $null)
{
  if ($reader)
  {
    $reader.Dispose() > $null
  }
  $reader = $null
  $cmd.Dispose() > $null
  $cmd = $null
  $con.Close() > $null
  $con.Dispose() > $null
  $con = $null
}

function get-command([System.Data.SQLite.SQLiteConnection] $con, [string] $cmdText)
{
  New-Object System.Data.SQLite.SQLiteCommand -ArgumentList $cmdText, $con
}

# Returns true if one (if $onlyone) or any (if not) uncommitted entry(ies) exist(s)
# If commented true, only if uncommitted entry has a comment.
function uncommitted-entry([bool] $onlyone, [bool] $commented = $False)
{
  $con = get-open-connection
  $cmd = get-command $con "SELECT 1 FROM Table1 where DateTimeOut is null$(if ($commented){' and Comment is not null'});"

  #$reader = $cmd.ExecuteReader([System.Data.CommandBehavior.CloseConnection])  can't figger it out.
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
  close-connection $con $cmd $reader
}

# Get unix epoch start time as DateTime.
function unix-epoch-starting-date-time()
{
  New-Object DateTime -ArgumentList 1970, 1, 1
}

# Get the unix time stamp for the time passed (or Now if none)
function get-unix-timestamp([AllowNull()] [System.Nullable``1[[System.DateTime]]] $dt = $null)
{
  if ($null -eq $dt) # you're supposed to compare to null this way: https://www.spcaf.com/blog/powershell-null-comparison/
  {
    $dt = [System.DateTime]::Now
  }
  $unixStart = unix-epoch-starting-date-time
  # demonic!  C# would require calling the Value property on the nullable type, but if we do that here, it bombs.
  [int]($dt.Subtract($unixStart)).TotalSeconds;
}

# Given a unix numeric time stamp, convert to DateTime.
function unix-stamp-to-date-time([AllowNull()] [System.Nullable``1[[int]]] $unixStamp = $null)
{
  if ($null -eq $unixStamp)
  {
    $unixStamp = get-unix-timestamp
  }
  $unixStartDate = unix-epoch-starting-date-time
  $unixStartDate.AddSeconds($unixStamp);
}

function get-last-task-filter
{
  "where rowid = (select max(rowid) from Table1 where DateTimeOut is not null)"
}

# Pre: uncommitted-entry returned true
# Returns time in, comment (if pass commented)
function get-uncommitted-details([bool] $commented)
{
  $con = get-open-connection
  $commentedAddOn = " and Comment is not null and Comment != `'`'"
  $cmd = get-command $con "select DateTimeIn, Comment FROM Table1 where DateTimeOut is null$(if ($commented){$commentedAddOn});"
  $reader = $cmd.ExecuteReader() #execute scalar doesn't seem to return anything.  It's not null, blank string, and debugger just shows nothing.
  # In PowerShell, the results of each statement are returned as output, even without a statement that contains the Return keyword
  $reader.Read() > $null
  # return hash table.  Array can have different types as well; would just be @($reader[0], $reader[1])
  @{TimeIn=$reader[0]; Comment=$reader[1]} # might both be null
  close-connection $con $cmd $reader
}

# Pre: uncommitted-entry returned true
function get-uncommitted-hours([bool] $commented = $False)
{
  $uncommitedDetails = get-uncommitted-details $commented
  if ($null -eq $uncommitedDetails.TimeIn)
  {
    0
  } else 
  {
    $timeInUnix = $uncommitedDetails.TimeIn
    $now = get-unix-timestamp
    $span = [System.TimeSpan]::FromSeconds($now - $timeInUnix)
    $result = [Math]::Round($span.TotalHours, 2)
    if ($result -lt 0) 
    {
      throw [System.Exception] "Calculated less than 0 in get-uncommitted-hours"
    }
    $result
  }
}

<# 
Comment all over is non-typed because powershell is a frickin mess with default null params WRT strings:
https://stackoverflow.com/questions/22906520/powershell-string-default-parameter-value-does-not-work-as-expected
#>
function ensure-non-empty-comment($comment) 
{
  if ($comment -eq '') 
  {
    throw [System.Exception] "Empty comment not allowed; expected null or non-empty string"
  }
}

# Returns past Sunday at midnight as DateTime local
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

<#
.Description
Note that comment may be added/modified at ClockOut.
#>
function ClockIn($comment)
{
  ensure-non-empty-comment $comment
  if (uncommitted-entry $False)
  {
    throw [System.Exception] "ClockIn: Uncommitted entry(ies).  Fix it."
  } else
  {
    $con = get-open-connection
    $now = get-unix-timestamp
    if ($comment)
    {
      $cmd = get-command $con "insert into Table1 (DateTimeIn, Comment) values($now, '$comment');"
    } else
    {
      $cmd = get-command $con "insert into Table1 (DateTimeIn) values($now);"
    }
    $cmd.ExecuteNonQuery() > $null
    close-connection $con $cmd
    Write-Output 'clocked in'
  }
}

<#
.Description
Expects one uncommitted entry.
#>
function ClockOut($comment)
{
  ensure-non-empty-comment $comment
  if (uncommitted-entry $True)
  {
    $now = get-unix-timestamp
    $uncommitedhours = get-uncommitted-hours
    $con = get-open-connection

    if ($comment)
    {
      $cmd = get-command $con "update Table1 set DateTimeOut = $now, Hours = $uncommitedhours, Comment = '$comment' where DateTimeOut is null;"
    } else
    {
      $cmd = get-command $con "update Table1 set DateTimeOut = $now, Hours = $uncommitedhours where DateTimeOut is null;"
    }
    $cmd.ExecuteNonQuery() > $null
    close-connection $con $cmd
    Write-Host 'clocked out, yo.'
  } else
  {
    throw [System.Exception] "ClockOut: expected one uncommitted entry.  Go fix."
  }
}

<#
.Description
If $thisWeek is true, just this week; else last week.
#>
function clock-week-commented($thisWeek)
{
  $con = get-open-connection
  $totalHours = 0
  $comments = ''
  $sunday = sunday
  $priorSunday = $sunday.AddDays(-7)
  if ($thisWeek) {
    # in case blank comments getting in.
    $cmd = get-command $con "select Hours, Comment from Table1 where DateTimeIn >= $(get-unix-timestamp (sunday)) and Comment is not null and Comment != '';"
  } else {
    $timeStampPriorSunday = get-unix-timestamp ($priorSunday)
    $timeStampThisSunday = get-unix-timestamp ($sunday)
    $cmd = get-command $con "select Hours, Comment from Table1 where (DateTimeIn >= $timeStampPriorSunday) and (DateTimeIn <= $timeStampThisSunday) and Comment is not null and Comment != '';"
  }
  $reader = $cmd.ExecuteReader()
  while ($reader.Read())
  {
    if ($reader[0] -is [System.DBNull])
    {
      # if (uncommitted-entry $True $True)
      # If current hours is null, there should be uncommitted totalHours.
      $currentHours = get-uncommitted-hours $True
    } else {
      $currentHours = [Math]::Round([double]$reader[0], 2)
    }
    $totalHours = [Math]::Round($totalHours + $currentHours, 2)

    if ($comments -ne '')
    {
      $comments = "$comments | "
    }
    # $comments = "$comments $($reader[1]$($currentHours))"
    $comments = $comments + ' ' + $reader[1] + '(' + $currentHours + ')'
  }
  close-connection $con $cmd $reader
  "$totalHours -> $comments"
}

<#
.Description
Returns hours for current week.
#>
function ClockWeekHours
{
  $con = get-open-connection
  $cmd = get-command $con "select sum(Hours) from Table1 where DateTimeIn >= $(get-unix-timestamp (sunday));"
  $reader = $cmd.ExecuteReader()
  $reader.Read() > $null # has rows even when no records!
  $readerresult = $reader[0]
  close-connection $con $cmd $reader
  $result = get-uncommitted-hours
  if ($readerresult -isnot [System.DBNull])
  {
    $result = $result + [double]$readerresult
  }
  $result
}

<#
.Description
Returns last week's hours (the week prior to last Sunday)
#>
function ClockLastWeekHours
{
  $con = get-open-connection
  $sunday = sunday
  $priorSunday = $sunday.AddDays(-7)
  $cmd = get-command $con "select sum(Hours) from Table1 where (DateTimeIn >= $(get-unix-timestamp ($priorSunday))) and (DateTimeIn < $(get-unix-timestamp ($sunday)));"
  $reader = $cmd.ExecuteReader()
  $reader.Read() > $null
  $readerresult = $reader[0]
  close-connection $con $cmd $reader
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
    $timeIn = unix-stamp-to-date-time $uncommitedDetails.TimeIn
    $timeUncommitted = [DateTime]::Now - $timeIn
    $hours = [Math]::Round($timeuncommitted.TotalHours, 2)
    $timeInStr = (unix-stamp-to-date-time $uncommitedDetails.TimeIn $True).ToShortTimeString()
    "Task with comment [$(if ($uncommitedDetails.Comment) {$uncommitedDetails.Comment})] in progress beginning $timeInStr with hours $hours"
  } else
  {
    "No tasks in progress"
  }
}

<#
.Description
Get the details of the last complete task.
#>
function ClockLastTask
{
  $con = get-open-connection
  $cmd = get-command $con "select strftime('%m-%d-%Y %H:%M', DateTimeIn, 'unixepoch'), strftime('%H:%M', DateTimeOut, 'unixepoch'), Hours, Comment from Table1 $(get-last-task-filter);"
  $reader = $cmd.ExecuteReader()
  $reader.Read() > $null
  if ($reader[0] -is [System.DBNull])
  {
    Write-Host "Last task not found."
  } else
  {
    Write-Host "Last task: In[$($reader[0])] Out[$($reader[1])] Hours[$($reader[2])] Comment[$($reader[3])]"
  }
  close-connection $con $cmd $reader
}

<#
.Description
Delete the last complete task.  If you have an uncompleted task you wish to delete, simply call ClockOut followed by this function.
#>
function ClockDeleteLastTask
{
  $con = get-open-connection
  $cmd = get-command $con "delete from Table1 $(get-last-task-filter);"
  $cmd.ExecuteNonQuery() > $null
  Write-Host "Last complete task deleted."
  close-connection $con $cmd
}

<#
.Description
Example: ClockAddTask '2-1-2019 10 AM' '2-1-2019 11:15 AM' 1.25 'Finished the ClockAddTask function.'
#>
function ClockAddTask([string] $dateTimeIn, [string] $dateTimeOut, [double] $hours, $comment)
{
  ensure-non-empty-comment $comment
  $convertedTimeIn = get-unix-timestamp ($dateTimeIn)
  $convertedTimeOut = get-unix-timestamp ($dateTimeOut)
  $con = get-open-connection
  if ($comment)
  {
    $cmd = get-command $con "insert into Table1 values($convertedTimeIn, $convertedTimeOut, $hours, '$comment');"
  } else 
  {
    $cmd = get-command $con "insert into Table1 values($convertedTimeIn, $convertedTimeOut, $hours, null);"
  }
  # No need for try-finally here.  It fails every which way without a complaint.
  $cmd.ExecuteNonQuery() > $null
  close-connection $con $cmd
}

<#
.Description
Useful for getting a timestamp to pass directly to SqLite when querying the DB directly.  $days is days to add to [now] and will usually be negative.
#>
function ClockGetTimeStamp([int] $days)
{
  $dt = [System.DateTime]::Now.AddDays($days)
  get-unix-timestamp ($dt)
}

<#
.Description
Returns hours, comments for tasks that are commented from the current week.
#>
function ClockWeekCommented {
  clock-week-commented $true
}

<#
.Description
Returns hours, comments for tasks that are commented from the prior week.
#>
function ClockLastWeekCommented {
  clock-week-commented $false
}

#get-unix-timestamp ([DateTime]::Now.AddDays(-4))
#unix-stamp-to-date-time
#ClockIn
#ClockOut "delete me"
#ClockStatus
#ClockLastWeekHours
#ClockWeekCommented $true
#ClockWeekCommented $false
#ClockWeekHours
#get-uncommitted-hours
#ClockLastTask
#ClockAddTask '3-21-2019' '3-21-2019' 0.58
#sunday
#unix-stamp-to-date-time 1552158835
#get-unix-timestamp (sunday)
#get-uncommitted-details

Export-ModuleMember -function ClockIn
Export-ModuleMember -function ClockOut
Export-ModuleMember -function ClockWeekHours
Export-ModuleMember -function ClockLastWeekHours
Export-ModuleMember -function ClockStatus
Export-ModuleMember -Function ClockWeekCommented
Export-ModuleMember -Function ClockLastWeekCommented
Export-ModuleMember -Function ClockAddTask
Export-ModuleMember -Function ClockLastTask
Export-ModuleMember -Function ClockDeleteLastTask
Export-ModuleMember -Function ClockGetTimeStamp
Export-ModuleMember -Function Hank

<#  can't get this to work
Set-Alias guh get-uncommitted-hours
Export-ModuleMember -function get-uncommitted-hours -Alias guh
#>

load-sqllite-type