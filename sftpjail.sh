#!/bin/sh
SSHD_CONFIG=/etc/ssh/sshd_config
DEFAULT_CHROOT='%h'
SFTPGROUP=sftpjail
SFTPUSER=sftpprisoner

if grep -q "Match Group ${SFTPGROUP}" $SSHD_CONFIG; then
    exit;
fi

if ! grep -q "^Subsystem\ssftp\sinternal-sftp" $SSHD_CONFIG; then
    sed -i".$(date --iso-8601=seconds).bak" 's/^[sS]ubsystem\ssftp\(.*\)/# Subsystem\tsftp\1\nSubsystem\tsftp\tinternal-sftp/g' $SSHD_CONFIG
fi

{
    echo "Match Group ${SFTPGROUP}"
    echo "    ChrootDirectory ${DEFAULT_CHROOT}"
    echo "    ForceCommand internal-sftp"
    echo "    AllowTcpForwarding no"
    echo "    X11Forwarding no"
} >> $SSHD_CONFIG
 
groupadd $SFTPGROUP
useradd -G $SFTPGROUP -s /sbin/nologin $SFTPUSER
SFTPUSER_HOME="$(getent passwd ${SFTPUSER} | cut -d: -f6)"
mkdir "$SFTPUSER_HOME"
chmod 755 "$SFTPUSER_HOME"

cd "$SFTPUSER_HOME" || exit
mkdir upload
mkdir download
mkdir .ssh
chown $SFTPUSER:$SFTPGROUP upload
chown $SFTPUSER:$SFTPGROUP download
chown $SFTPUSER:$SFTPGROUP .ssh

PASSPHRASE="$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c"${1:-64}")"
printf "The passphrase for the sshkey:%s\n" "$PASSPHRASE"
SSHKEY="${SFTPUSER_HOME}"/.ssh/sftpkey
PUBKEY="${SSHKEY}".pub
AUTHKEYS="${SFTPUSER_HOME}"/.ssh/authorized_keys
ssh-keygen -f "${SSHKEY}" -ted25519 -N "${PASSPHRASE}"
cat "${PUBKEY}" >> "${AUTHKEYS}"
chown $SFTPUSER:$SFTPGROUP "${SSHKEY}" "${PUBKEY}" "${AUTHKEYS}"
chmod 600 "${SSHKEY}"
