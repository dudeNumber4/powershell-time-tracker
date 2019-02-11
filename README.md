# PowerShell-time-tracker
Simple time tracking system (tracks hours).  Currently reports time by week.  Command line interface via PowerShell.  I run many things using PowerShell, so I always have a PowerShell command window open, but you could start one every time you want to run a command.

# Dependencies
* PowerShell v6 (Core).  Cross platform.
* SQLite nuget package for .Net core.  https://www.nuget.org/packages/System.Data.SQLite/
* While there are no other dependencies, having the SQLite tools would be handy.  For instance, currently, if you call ClockIn and there is already an uncommitted task, the error will tell you that some task hasn't been finished, "Fix it."  Without SQLite, you wouldn't be able to manually go into the table and remove the uncommitted task if it's something you wanted to just delete.  You would probably have to issue 'ClockOut "disregard this task"'.  Here are the functions that would be handy for non-SQLite users (if anyone ever requests them, I will add, but I just do these manually in those rare circumstances):
  * ClockDeleteCurrentTask
  * ClockDeleteTasks Date

## Help
* In powershell typing clock+ctrl+space will show all available commands beginning with "clock."
* Get-Help <command> will show the parameters / help for the command.

## Commands
* ClockIn <comment>.  Start timing a task.  Comment optional.
* ClockOut <comment>.  Stop a task in progress.  Comment optional.  Comment at ClockOut will overwrite ClockIn comment.
* ClockWeekHours.  Report hours for current week (Sunday - Saturday)
* ClockLastWeekHours.  Report hours for last week (Sunday - Saturday starting at the Sunday prior to last).  I found myself needing this when working on the weekend.
* ClockWeekCommented.  Report hours and comments for tasks this week that include comments.  I use this (I add comments) for tasks that I consider a separate "category."
* ClockStatus.  Report current task and hours taken so far.
* ClockLastTask.  Details of the last complete task.
* ClockAddTask.  Manually add a task.

### Configure
* Grab the nuget package mentioned in dependencies.
* Set the path to that nuget package in function get-open-connection.
* Set the path to TimeTracker.db (starter database) in function get-open-connection.  If you ever need to recreate that database, it just has one table:
  * `create table Table1(DateTimeIn int, DateTimeOut int, Hours real, Comment varchar(512));`
* Add TimeTracker.psm1 to PowerShell profile.  To configure a profile and reference a separate psm1 file, see this old post (which is still relevant for PowerShell 6) https://codejournal.blogspot.com/2018/08/using-PowerShell-as-command-alias-runner.html.  For redirecting to a file in a location of your choice, see https://stackoverflow.com/questions/5095509/is-it-possible-to-change-the-default-value-of-profile-to-a-new-value (see Root Loop's answer).
* Test configuration via ClockStatus function.