# aliceBackup
Do not add in production. In extremely beta phase.

## USAGE
```
--source=
--exclude-this=
--port=MyPortSSH
--id-rsa=/local/id_rsa
rsync://User@example.com:/DirectoryBackupServer
--help
```

<<<<<<< HEAD
```
## ROADMAP alicebackup-client.sh
```
>>>>>>> main
-[ ] (Implement backup restore method with tar + rsync + ssh.)
-[ ] (Implement Criptography with gpg key)
-[ ] (Create check for No space left on device.)
-[ ] (Create complete log system.)
-[ ] (Create FULL Documentation + FULL examples of use.)
```
### alicebackup-client.sh
* Responsible for creating the backup and sending it to the backup server.

### alicebackup-server.sh
* It is located on the backup server. Cleans backups every 'n' days. As you define.
