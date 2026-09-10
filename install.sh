#!/bin/bash
# ==========================================
# AUTO INSTALLER SSH & DROPBEAR ENHANCED + WS
# ==========================================

GREEN='\033[0;32m'
NC='\033[0m'
REPO_URL="https://raw.githubusercontent.com/WBVPN/ssh-dropbear-enhanced/main"

clear
echo -e "${GREEN}[*] Memulai Instalasi SSH Dropbear Enhanced & Websocket...${NC}"

# 0. DISABLE IPV6 (Pencegahan DNS Leak & RTO)
echo -e "${GREEN}[*] Mematikan Protokol IPv6 di Kernel Linux...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
sysctl -w net.ipv6.conf.lo.disable_ipv6=1 &>/dev/null
cat << SYSCTL >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
SYSCTL
sysctl -p &>/dev/null

# 1. SETUP DOMAIN & VALIDASI IP
echo -e "${GREEN}[*] Setup Domain SSH Websocket${NC}"
VPS_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me)

while true; do
    read -p "Masukkan Domain Anda: " domain
    echo -e "Memvalidasi pointing DNS untuk $domain..."
    
    # Validasi DNS (Menggunakan ping bawaan OS)
    DOMAIN_IP=$(ping -c 1 -W 2 $domain 2>/dev/null | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
    
    if [ -z "$DOMAIN_IP" ]; then
        echo -e "\033[0;31m[!] GAGAL: Domain tidak memiliki Record IP / DNS belum menyebar.\033[0m"
        echo -e "Silakan coba lagi.\n"
    elif [ "$DOMAIN_IP" == "$VPS_IP" ]; then
        echo -e "${GREEN}[V] SUKSES: Pointing Valid! ($DOMAIN_IP)\033[0m"
        break
    else
        echo -e "\033[0;31m[!] DITOLAK: IP Domain ($DOMAIN_IP) tidak cocok dengan IP VPS ($VPS_IP).\033[0m"
        echo -e "Pastikan domain sudah dipointing dengan benar dan Awan Cloudflare (Proxied) dimatikan. Coba lagi.\n"
    fi
done

echo "$domain" > /root/domain
echo -e "Domain Anda tersimpan: $domain"

# 2. UPDATE & INSTALL DEPENDENCIES
apt-get update -y
apt-get install -y gcc make build-essential zlib1g-dev libpam0g-dev wget bzip2 python3 socat nginx

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
echo -e "Mem-bypass dialog interaktif OS dan mengunduh source..."

# Matikan dialog ungu (needrestart) dan APT UI yang bikin hang
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'a';" > /etc/needrestart/conf.d/restart.conf
systemctl stop dropbear &>/dev/null
apt-get purge -y --force-yes dropbear &>/dev/null
rm -rf /etc/dropbear /usr/sbin/dropbear /usr/lib/dropbear

cd /usr/local/src
# Mengunduh Source Tarball ASLI (sudah ada ./configure) dari Mirror Repositori Github kita sendiri
wget -q --show-progress --timeout=10 --no-check-certificate -O dropbear-2019.78.tar.bz2 https://raw.githubusercontent.com/WBVPN/ssh-dropbear-enhanced/main/dropbear-2019.78.tar.bz2
tar -xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78

# Redirect output make ke log agar layar tidak kotor, tetapi kompilasi tetap jalan
./configure --disable-zlib --enable-pam > /tmp/dropbear_build.log 2>&1
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
echo "Mengunduh ws-stunnel..."
wget -q --timeout=10 -4 -O /usr/local/bin/ws-stunnel ${REPO_URL}/ws-stunnel
echo "Mengunduh ws-stunnel.service..."
wget -q --timeout=10 -4 -O /etc/systemd/system/ws-stunnel.service ${REPO_URL}/ws-stunnel.service
chmod +x /usr/local/bin/ws-stunnel
chmod +x /etc/systemd/system/ws-stunnel.service

# 6. CONFIG NGINX SEBAGAI REVERSE PROXY SSL & WS
echo "Menulis konfigurasi Nginx..."
cat << NGINXCONF > /etc/nginx/conf.d/ssh-ws.conf
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
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
# 9. AUTO-START MENU SAAT LOGIN
echo -e "${GREEN}[*] Mengatur Auto-Start Menu...${NC}"
if ! grep -q "/usr/local/bin/menu" /root/.profile; then
    echo "clear" >> /root/.profile
    echo "/usr/local/bin/menu" >> /root/.profile
fi

echo -e "Sekarang, setiap kali Anda login ke VPS, menu akan terbuka otomatis!"
