#!/bin/zsh

###############################################
#  V0.1 - 15/06/2024
#  Thomas Eeles. 
#  Ubuntu SSH Jailhouse Setup Script
#  A script to create a secure SFTP drop server.  
###############################################

#### Variables ####
PASS=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | head -c 20)
PASS2=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | head -c 20)
PASS3=$(openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | head -c 20)
KEY="/home/teeles/key.txt"

#### Functions ####

Ubuntu_Version() {
    local release_version=$(lsb_release -r | awk '{print $2}')

    if [[ $release_version == 24.* ]]; then
        echo "We are running Ubuntu 24 LTS, good."
        echo "Running update and upgrade..."
        
        # Update and upgrade commands with proper error handling
        if apt update && apt upgrade -y; then
            echo "Update and upgrade completed successfully."
        else
            echo "Error occurred during update and upgrade."
            exit 1
        fi
    else
        echo "This script needs to be run on Ubuntu 24 LTS, exit time."
        exit 1
    fi
}


#### THE SCRIPT ####

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run the script using the 'sudo' command"
  exit 1
fi

echo "   This script will set up this server as a ShowMeTheLogs SSH Jail.                  "

touch "$KEY"
chown teeles:teeles "$KEY"
chmod 600 "$KEY"

Ubuntu_Version

#Create the first users
echo "Creating SFTP users"

useradd -M -s /usr/sbin/nologin sftpwin
echo "sftpwin:$PASS" | chpasswd
echo "sftpwin $PASS" > "$KEY"

useradd -M -s /usr/sbin/nologin sftpmac
echo "sftpmac:$PASS2" | chpasswd
echo "sftpmac $PASS2" >> "$KEY"

useradd -m sftpadmin
echo "sftpadmin:$PASS3" | chpasswd
echo "sftpadmin $PASS3" >> "$KEY"

#Creating SFTP User Groups
echo "Creating SFTP Groups"

groupadd sftpusers
usermod -aG sftpusers sftpwin
usermod -aG sftpusers sftpmac

groupadd sftpowners
usermod -aG sftpowners sftpadmin

# Setup the folder structure
echo "setting up the file structure"

mkdir /home/sftp
chown :sftpowners /home/sftp
chmod 770 /home/sftp

mkdir /home/sftp/win
chown root:root /home/sftp/win
chmod 755 /home/sftp/win
mkdir /home/sftp/win/upload
chown sftpwin:sftpusers /home/sftp/win/upload
chmod 770 /home/sftp/win/upload


mkdir /home/sftp/mac
chown root:root /home/sftp/mac
chmod 770 /home/sftp/mac
mkdir /home/sftp/mac/upload
chown sftpmac:sftpusers /home/sftp/win/upload
chmod 770 /home/sftp/mac/upload

echo "setting up SFTP config"

cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bk"

cat <<EOL >> /etc/ssh/sshd_config
Match User sftpwin
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /home/sftp/win
    ForceCommand internal-sftp

Match User sftpmac
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /home/sftp/mac
    ForceCommand internal-sftp
EOL

# Restart SSH service to apply changes
echo "Restarting SSH service"
if systemctl restart ssh; then
    echo "SSH service restarted successfully."
else
    echo "Failed to restart SSH service."
    exit 1
fi

echo "SFTP JAIL SETUP COMPLETED SUCCESSFULLY"
