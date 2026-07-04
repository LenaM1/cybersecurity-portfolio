#!/bin/bash

# ============================================================
# your_script.sh
# Purpose: Automate routine system maintenance tasks:
#   1. Disk usage check + deletion of logs older than 7 days
#   2. Reboot notification message
#   3. File organization (.txt / .log -> organized folder)
#   4. Timestamped backup of important files
# All actions are logged to /home/$USER/script_log.txt
# ============================================================

# ---- Configuration ----
LOG_DIR="$HOME/logs"                # directory to scan for old logs
ORGANIZE_SRC="$HOME/Downloads"      # directory to scan for .txt/.log files
ORGANIZE_DEST="$HOME/organized"     # destination for organized files
BACKUP_SRC="$HOME/data"             # directory to back up
BACKUP_DEST="$HOME/backups"         # where backups are stored
LOG_FILE="$HOME/script_log.txt"     # script's own action log
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")

# ---- Helper function: log + print a message ----
log_message() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" | tee -a "$LOG_FILE"
}

# Make sure destination directories exist before we use them
mkdir -p "$ORGANIZE_DEST" "$BACKUP_DEST"

log_message "===== Script started ====="

# ------------------------------------------------------------
# 1. SYSTEM MAINTENANCE: check disk usage, remove logs > 7 days
# ------------------------------------------------------------
log_message "Checking disk usage..."
df -h | tee -a "$LOG_FILE"

if [ -d "$LOG_DIR" ]; then
    log_message "Searching for .log files older than 7 days in $LOG_DIR..."
    # Loop over matching files so each deletion can be logged individually
    find "$LOG_DIR" -name "*.log" -mtime +7 | while read -r old_log; do
        rm "$old_log"
        log_message "Deleted old log file: $old_log"
    done
else
    log_message "Log directory $LOG_DIR not found, skipping cleanup."
fi

# ------------------------------------------------------------
# 2. USER NOTIFICATION: warn before a simulated update/reboot
# ------------------------------------------------------------
log_message "System will reboot soon"
echo "System will reboot soon"

# Bonus: give the user a chance to cancel before continuing
read -p "Do you want to continue with maintenance? (y/n): " choice
if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
    log_message "User chose to stop the script. Exiting."
    exit 0
fi

# ------------------------------------------------------------
# 3. FILE ORGANIZATION: move .txt/.log files to a dedicated folder
# ------------------------------------------------------------
if [ -d "$ORGANIZE_SRC" ]; then
    log_message "Organizing .txt and .log files from $ORGANIZE_SRC..."
    for file in "$ORGANIZE_SRC"/*.txt "$ORGANIZE_SRC"/*.log; do
        # Skip the literal pattern if no files match (glob doesn't expand)
        [ -e "$file" ] || continue
        mv "$file" "$ORGANIZE_DEST/"
        log_message "Moved $(basename "$file") to $ORGANIZE_DEST"
    done
else
    log_message "Source directory $ORGANIZE_SRC not found, skipping organization."
fi

# ------------------------------------------------------------
# 4. BACKUP AUTOMATION: timestamped archive of important files
# ------------------------------------------------------------
if [ -d "$BACKUP_SRC" ]; then
    BACKUP_FILE="$BACKUP_DEST/backup_$TIMESTAMP.tar.gz"
    tar -czf "$BACKUP_FILE" "$BACKUP_SRC"
    log_message "Backup created: $BACKUP_FILE"
else
    log_message "Backup source $BACKUP_SRC not found, skipping backup."
fi

log_message "===== Script finished ====="
echo "All tasks complete. See $LOG_FILE for details."


# This script: automates four routine maintenance tasks on a Linux system: it checks disk usage and deletes .log files older than 7 days from a logs directory; it displays a "System will reboot soon" notification and asks the user for confirmation before proceeding; it organizes stray .txt and .log files from a Downloads folder into a dedicated organized/ directory; and it creates a timestamped .tar.gz backup of an important data directory. Every action — disk check, each file deleted, each file moved, and the backup path — is timestamped and written to /home/$USER/script_log.txt via a shared log_message() function, so there's a full audit trail of what the script did on each run.
# How I tested it: I created a sandbox $HOME with a logs/ folder containing one file backdated 10 days (via touch -d) and one recent file, a Downloads/ folder with a .txt and .log file, and a data/ folder with a sample file. Running the script confirmed the old log was deleted while the recent one was untouched, both Downloads files were moved into organized/, a timestamped backup archive was created in backups/, and every step appeared correctly in script_log.txt. I also ran bash -n to check syntax before executing.
# Challenges: The original draft I was reviewing had several bugs that would have caused silent failures — an unquoted *.logs pattern that didn't match real .log files, string-equality checks ([ "$file" = ".txt" ]) that only match an exact filename rather than an extension, and variables ($system, $cleanup, $files) that were never actually defined anywhere in the script. The main fix was replacing single-file conditionals with a for/while loop that iterates over real matches in the filesystem, and adding mkdir -p guards so the script doesn't fail if a target directory doesn't exist yet.