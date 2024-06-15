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

echo "##### SFTP JAIL SETUP SCRIPT ####"
echo "Welcome to the RM SFTP JAIL Setup Script"

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
useradd -M -s /usr/sbin/nologin sftpowner
echo "sftpowner:$PASS3" | chpasswd
echo "sftpowner $PASS3" >> "$KEY"
echo "Creating SFTP Groups"
groupadd sftpusers
usermod -aG sftpusers sftpowner

# Setup the folder structure
echo "setting up the file structure"

mkdir /var/sftp
chown sftpowner:sftpusers /var/sftp
chmod 775 /var/sftp

mkdir /var/sftp/win
chown sftpwin:sftpwin /var/sftp/win
chmod 300 /var/sftp/win

mkdir /var/sftp/mac
chown sftpmac:sftpmac /var/sftp/mac
chmod 300 /var/sftp/mac

echo "setting up SFTP config"

cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bk"

cat <<EOL >> /etc/ssh/sshd_config
Match User sftpwin
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /var/sftp/win
    ForceCommand internal-sftp

Match User sftpmac
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /var/sftp/mac
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

