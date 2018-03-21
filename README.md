# cisco-backup-git
# Description
This script allows network backups of Cisco switches and routers.
It stores the configs in git repositories.

# How to use
```sh
./cisco-backup-git.sh -f dev.lst -d ../backup/ -n 8 -c "some changes description"
```

```sh
./cisco-backup-git.sh -f dev.lst -d ../backup/ -n "29 30" -c "back up devices with number 29 and 30 from the configuration file"
```

```sh
./cisco-backup-git.sh -f dev.lst -d ../backup/ -c "backup all devices from the configuration file"
```

# cisco backup user example
```
username backup privilege 3 secret 0 PASSWORD
privilege exec all level 3 show running-config
```
