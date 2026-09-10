#!/bin/bash
# ==========================================
# AUTO INSTALLER SSH & DROPBEAR ENHANCED
# Dropbear Version: 2019.78 (Legacy Enhanced)
# ==========================================

# Print Color
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Memulai Instalasi SSH & Dropbear Enhanced (2019.78)...${NC}"

# Update & Install Dependencies
apt-get update -y
apt-get install -y gcc make build-essential zlib1g-dev wget bzip2

# Hapus Dropbear bawaan OS jika ada
systemctl stop dropbear &>/dev/null
apt-get purge dropbear -y &>/dev/null
rm -rf /etc/dropbear /usr/sbin/dropbear /usr/lib/dropbear

# Download Source Dropbear 2019.78
cd /usr/local/src
wget -q --no-check-certificate -O dropbear-2019.78.tar.bz2 https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2
tar -xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78

# Konfigurasi & Kompilasi
# Mengaktifkan Password Auth dan menonaktifkan zlib bawaan untuk kompatibilitas tunnel
./configure --disable-zlib --enable-pam --enable-password-auth
make
make install

# Pindahkan binary agar sesuai standar service linux
cp dropbear /usr/sbin/dropbear
mkdir -p /etc/dropbear

# Generate Keys
echo -e "${GREEN}Membangun RSA/DSS/ECDSA Keys untuk Dropbear...${NC}"
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
chmod 600 /etc/dropbear/*_host_key

# Konfigurasi Port
cat << 'CONFIG' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
CONFIG

# Setup Systemd Service
cat << 'SERVICE' > /etc/systemd/system/dropbear.service
[Unit]
Description=Dropbear Lightweight SSH Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/default/dropbear
ExecStart=/usr/sbin/dropbear -F -E -p ${DROPBEAR_PORT} $DROPBEAR_EXTRA_ARGS
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

# Mulai Layanan Dropbear
systemctl daemon-reload
systemctl enable dropbear
systemctl restart dropbear

echo -e "${GREEN}Instalasi Selesai!${NC}"
echo -e "Dropbear berjalan di Port: 143, 109"
echo -e "Cek status: systemctl status dropbear"
