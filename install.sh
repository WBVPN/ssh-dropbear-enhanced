#!/bin/bash
# ==========================================
# AUTO INSTALLER SSH & DROPBEAR ENHANCED + WS
# ==========================================

GREEN='\033[0;32m'
NC='\033[0m'
REPO_URL="https://raw.githubusercontent.com/WBVPN/ssh-dropbear-enhanced/main"

clear
echo -e "${GREEN}[*] Memulai Instalasi SSH Dropbear Enhanced & Websocket...${NC}"

# 1. SETUP DOMAIN
echo -e "${GREEN}[*] Setup Domain SSH Websocket${NC}"
read -p "Masukkan Domain Anda: " domain
echo "$domain" > /root/domain
echo -e "Domain Anda tersimpan: $domain"

# 2. UPDATE & INSTALL DEPENDENCIES
apt-get update -y
apt-get install -y gcc make build-essential zlib1g-dev wget bzip2 python3 socat nginx

# 3. SETUP SSL (Acme.sh)
echo -e "${GREEN}[*] Menginstall Sertifikat SSL untuk $domain...${NC}"
systemctl stop nginx
mkdir -p /root/.acme.sh
curl -sL https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/ssl/private/fullchain.cer --keypath /etc/ssl/private/private.key --ecc

# 4. INSTALL DROPBEAR 2019.78
echo -e "${GREEN}[*] Kompilasi Dropbear 2019.78 Enhanced...${NC}"
echo -e "Mohon tunggu 1-3 menit. Proses pengunduhan dan kompilasi sedang berjalan..."
systemctl stop dropbear &>/dev/null
apt-get purge dropbear -y &>/dev/null
rm -rf /etc/dropbear /usr/sbin/dropbear /usr/lib/dropbear

cd /usr/local/src
# Menggunakan --show-progress agar terlihat jika server Dropbear Australia sedang lambat (dan tidak terkesan mentok)
wget -q --show-progress --no-check-certificate -O dropbear-2019.78.tar.bz2 https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2
tar -xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78

# Redirect output make ke log agar layar tidak kotor, tetapi kompilasi tetap jalan
./configure --disable-zlib --enable-pam --enable-password-auth > /tmp/dropbear_build.log 2>&1
make >> /tmp/dropbear_build.log 2>&1
make install >> /tmp/dropbear_build.log 2>&1
cp dropbear /usr/sbin/dropbear
mkdir -p /etc/dropbear

dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
chmod 600 /etc/dropbear/*_host_key

cat << 'CONFIG' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
CONFIG

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

# 5. INSTALL WEBSOCKET PYTHON (WS-STUNNEL)
echo -e "${GREEN}[*] Menginstall SSH Websocket (Python)...${NC}"
wget -q -O /usr/local/bin/ws-stunnel ${REPO_URL}/ws-stunnel
wget -q -O /etc/systemd/system/ws-stunnel.service ${REPO_URL}/ws-stunnel.service
chmod +x /usr/local/bin/ws-stunnel
chmod +x /etc/systemd/system/ws-stunnel.service

# 6. CONFIG NGINX SEBAGAI REVERSE PROXY SSL & WS
cat << NGINXCONF > /etc/nginx/conf.d/ssh-ws.conf
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/ssl/private/fullchain.cer;
    ssl_certificate_key /etc/ssl/private/private.key;

    location / {
        proxy_pass http://127.0.0.1:10015; # Port bawaan WS Wibulite
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
NGINXCONF

# 7. MULAI LAYANAN
systemctl daemon-reload
systemctl enable dropbear
systemctl restart dropbear
systemctl enable ws-stunnel
systemctl restart ws-stunnel
systemctl enable nginx
systemctl restart nginx

# 8. INSTALL MENU
echo -e "${GREEN}[*] Memasang Menu Pengelola SSH...${NC}"
wget -q -O /usr/local/bin/menu ${REPO_URL}/menu.sh
chmod +x /usr/local/bin/menu

echo -e "${GREEN}[*] Instalasi Selesai!${NC}"
echo -e "Ketik perintah: 'menu' di terminal untuk membuka panel kelola akun SSH."
