# aliceBackup
aliceBackup is a backup tool that creates (Full and Differential Backup) for GNU/Linux. Created in Posix Shell and simple tools such as: (cut, grep, rsync, tar)

## Tool cycle
You may be asking yourself **"With so many tools available, is this tool right for me...?"**
Let's point out some points of operation.

aliceBackup runs only on the client side, that is, your machines are backed up and sent every (X) time to a Linux server and are immediately deleted from your local machine. RSYNC + SSH is used for transport.
Connection is made via ssh keys. That's why it's important that you have an ssh key configured!

## Configure
The first time it is run you must use the **--configure-me** for the first settings.

## VERSION
Beta - Don't use in production.

## ROADMAP

 - [ ] Create a complete log system and send it to [backup server] along with the log?

## TODO

 - Improve part about deleting files on the remote server every X days. Standard 15 days. It does not need to be run every time each backup.
 - Simplify code and modularize

### License
GPLv3
