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
CONF=/etc/ssh/sshd_config
SEARCH="Subsystem sftp /usr/lib/openssh/sftp-server"
NEW_LINE="Subsystem sftp internal-sftp"

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

groupadd sftponly

useradd -g sftponly -s /bin/false -m -d /home/sftpwin sftpwin
echo "sftpwin:$PASS" | chpasswd
echo "sftpwin $PASS" > "$KEY"
useradd -g sftponly -s /bin/false -m -d /home/sftpmac sftpmac
echo "sftpmac:$PASS2" | chpasswd
echo "sftpmac $PASS2" >> "$KEY"

useradd -m sftpadmin
echo "sftpadmin:$PASS3" | chpasswd
echo "sftpadmin $PASS3" >> "$KEY"
usermod -aG sudo sftpadmin

echo "Changing Home Driectory Permissions"
chown root: /home/sftpwin
chmod 755 /home/sftpwin
chown root: /home/sftpmac
chmod 755 /home/sftpmac

echo "creating new upload folders and setting Permissions"
mkdir /home/sftpwin/up
chmod 755 /home/sftpwin/up
chown sftpwin:sftponly /home/sftpwin/up
mkdir /home/sftpmac/up
chmod 755 /home/sftpmac/up
chown sftpmac:sftponly /home/sftpmac/up

echo "setting up sshd_config files"
cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bk"
sed -i "/^$SEARCH/ s|^|#|" $CONF
sed -i "/$NEW_LINE/d" $CONF
sed -i "/$SEARCH/a\$NEW_LINE" $CONF

cat <<EOL >> /etc/ssh/sshd_config
Match Group sftponly
ChrootDirectory %h
ForceCommand internal-sftp
AllowTcpForwarding no
X11Forwarding no
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
