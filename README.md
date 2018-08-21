# powershell-time-tracker
Simple time tracking system (tracks hours).  Currently reports time by week.  Command line interface via powershell.  I run many things using powershell, so I always have a powershell command window open, but you could start one every time you want to run a command.

## Commands
* ClockIn.  Start timing a task.  Comment optional.
* ClockOut.  Stop a task in progress.  Comment optional.  Comment at ClockOut will overwrite ClockIn comment.
* ClockWeekHours.  Report hours for current week (Sunday - Saturday)
* ClockWeekCommented.  Report hours and comments for tasks this week that include comments.  I use this (I add comments) for tasks that I consider a separate "category."
* ClockStatus.  Report current task and hours taken so far.

### Configure
* Powershell: windows only of course.
* Requires Microsoft Access Database Engine 2016 Redistributable.  Most windows machines will already have it, but direct download of install can be found here: https://www.microsoft.com/en-us/download/confirmation.aspx?id=54920  If you're not sure, just continue with the rest of the configuration and the first time you attempt to run any command, you'll get a message saying you need it if so.
* Copy TimeTracker.accdb wherever you want it to live.
* Add TimeTracker.psm1 to powershell profile.  To configure a profile and reference a separate psm1 file, see https://codejournal.blogspot.com/2018/08/using-powershell-as-command-alias-runner.html
* Set the path to TimeTracker.accdb in TimeTracker.psm1, line 3.