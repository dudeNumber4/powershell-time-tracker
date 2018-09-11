# powershell-time-tracker
Simple time tracking system (tracks hours).  Currently reports time by week.  Command line interface via powershell.  I run many things using powershell, so I always have a powershell command window open, but you could start one every time you want to run a command.

# Dependencies
* Powershell: windows only of course.
* Microsoft Access Database Engine Redistributable.  See Configure; it's free.
* While there are no other dependencies, having MS Access would be handy.  For instance, currently, if you call ClockIn and there is already an uncommitted task, the error will tell you that some task hasn't been finished, "Fix it."  Without Access, you wouldn't be able to manually go into the table and remove the uncommitted task if it's something you wanted to just delete.  You would probably have to issue 'ClockOut "disregard this task"'.  Here are the functions that would be handy for non-Access users (if anyone ever requests them, I will add, but I just do these manually in those rare circumstances):
  * ClockDeleteCurrentTask
  * ClockAddTask DateTimeStart DateTimeEnd <"comment">
  * ClockDeleteTasks Date


## Commands
* ClockIn <comment>.  Start timing a task.  Comment optional.
* ClockOut <comment>.  Stop a task in progress.  Comment optional.  Comment at ClockOut will overwrite ClockIn comment.
* ClockWeekHours.  Report hours for current week (Sunday - Saturday)
* ClockLastWeekHours.  Report hours for last week (Sunday - Saturday starting at the Sunday prior to last).  I found myself needing this when working on the weekend.
* ClockWeekCommented.  Report hours and comments for tasks this week that include comments.  I use this (I add comments) for tasks that I consider a separate "category."
* ClockStatus.  Report current task and hours taken so far.

### Configure
* Requires Microsoft Access Database Engine 2016 Redistributable.  Most windows machines will already have it, but direct download of install can be found here: https://www.microsoft.com/en-us/download/confirmation.aspx?id=54920  If you're not sure, just continue with the rest of the configuration and the first time you attempt to run any command, you'll get a message saying you need it if so.
* Copy TimeTracker.accdb wherever you want it to live.
* Add TimeTracker.psm1 to powershell profile.  To configure a profile and reference a separate psm1 file, see https://codejournal.blogspot.com/2018/08/using-powershell-as-command-alias-runner.html
* Set the path to TimeTracker.accdb in TimeTracker.psm1, line 3.