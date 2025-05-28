#!/bin/bash

LOG_FILE="/home/heritp/system_maintenance.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

init_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
        echo "[$TIMESTAMP] LOG INIT: Created log file." | sudo tee -a "$LOG_FILE" > /dev/null
    fi
}

add_record() {
    local TASK="$1"
    local MESSAGE="$2"
    echo "[$TIMESTAMP] $TASK: $MESSAGE" | sudo tee -a "$LOG_FILE" > /dev/null
}

delete_old_files() {
    local DIR="$1"
    local DAYS="$2"

    if [ ! -d "$DIR" ]; then
        add_record "CLEANUP" "Failed: $DIR"
        exit 1
    fi

    find "$DIR" -type f -mtime +"$DAYS" -print -delete 2>/tmp/cleanup_errors.log
    if [ $? -eq 0 ]; then
        add_record "CLEANUP" "Success -Deleted files older than $DAYS days from $DIR"
    else
        add_record "CLEANUP" "Failed"
    fi
}

backup_files() {                                                    #Here as you can see there are two arguments required to be passed for the backup to run manually
    local DIR="$1"
    local DAYS="$2"                                                 #Now the crontab can take only one command or directory path after the defining of automation period                                                                       
    local BACKUP_NAME="backup_$TIMESTAMP.tar.gz"                    #So what change should i make to automate the task using cron and 1 command
    local DEST="/var/backups"

    if [ ! -d "$DIR" ]; then
        add_record "BACKUP" "Failed: $DIR"
        exit 1
    fi

    mkdir -p "$DEST"
    find "$DIR" -type f -mtime -"$DAYS" -print | tar -czf "$DEST/$BACKUP_NAME" -T -

    if [ $? -eq 0 ]; then
        add_record "BACKUP" "Success Created backup $DEST/$BACKUP_NAME"
    else
        add_record "BACKUP" "Failed to archieve"
    fi
}

show_logs() {
    echo "Last 5 Entries"
    sudo tail -n 5 "$LOG_FILE"
}

cleanup_logs() {
    TMP_FILE=$(mktemp)  #Temporary file
    sudo awk -v date="$(date -d '30 days ago' +%Y-%m-%d)" '$0 ~ /^\[[0-9]{4}-[0-9]{2}-[0-9]{2}/ {                  
        split($0, a, " ")  
        gsub(/[\[\]]/, "", a[1])
        if (a[1] >= date) print $0 
 }' "$LOG_FILE" > "$TMP_FILE"                                    
    sudo mv "$TMP_FILE" "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
}

main() {
    init_log_file
    cleanup_logs

    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  $0 --backup <directory> <days>"
        echo "  $0 --cleanup <directory> <days>"
        echo "  $0 --show-logs"
        exit 1
    fi

    case "$1" in
        --backup)
            add_record "SCRIPT" "Backup manually."
            backup_files "$2" "$3"
            ;;
        --cleanup)
            add_record "SCRIPT" "Cleanup manually."
            delete_old_files "$2" "$3"
            ;;
        --show-logs)
            show_logs
            ;;
        *)
            echo "Unknown command: $1"
            ;;
    esac
}

main "$@"
