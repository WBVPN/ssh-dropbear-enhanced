#!/bin/bash
# ==========================================
# MENU MANAGER SSH & DROPBEAR ENHANCED
# ==========================================

# Warna
BGreen='\e[1;32m'
BRed='\e[1;31m'
BBlue='\e[1;34m'
BYellow='\e[1;33m'
BWhite='\e[1;37m'
NC='\e[0m'

clear
echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BWhite}          PANEL MANAGER SSH & DROPBEAR           ${NC}"
echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e ""
echo -e "  ${BYellow}[ 1 ]${NC} ${BWhite}Buat Akun SSH & Dropbear${NC}"
echo -e "  ${BYellow}[ 2 ]${NC} ${BWhite}Hapus Akun SSH & Dropbear${NC}"
echo -e "  ${BYellow}[ 3 ]${NC} ${BWhite}Perpanjang Akun SSH${NC}"
echo -e "  ${BYellow}[ 4 ]${NC} ${BWhite}Cek User Login (Online)${NC}"
echo -e "  ${BYellow}[ 5 ]${NC} ${BWhite}List Semua Akun SSH${NC}"
echo -e "  ${BRed}[ x ]${NC} ${BWhite}Keluar${NC}"
echo -e ""
echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "  Pilih Menu [1-5 / x] : " menu_idx

case $menu_idx in
    1)
        clear
        echo -e "${BGreen}=== BUAT AKUN SSH ===${NC}"
        read -p "Username : " Login
        read -p "Password : " Pass
        read -p "Expired (Hari) : " masaaktif
        
        # Validasi ketersediaan user (dan group bentrok)
        if id "$Login" &>/dev/null; then
            echo -e "${BRed}User $Login sudah ada di sistem!${NC}"
            exit 1
        fi
        if getent group "$Login" &>/dev/null; then
            echo -e "${BRed}Nama $Login bentrok dengan grup bawaan sistem. Gunakan nama lain!${NC}"
            exit 1
        fi
        
        exp=$(date -d "+${masaaktif} days" +"%Y-%m-%d")
        
        # Eksekusi Pembuatan User dengan Validasi Error
        if ! useradd -e "$exp" -s /bin/false -M "$Login" 2>/dev/null; then
            echo -e "${BRed}[!] FATAL: Gagal membuat user $Login di OS.${NC}"
            exit 1
        fi
        
        # Eksekusi Password
        if ! echo -e "$Login:$Pass" | chpasswd 2>/dev/null; then
            echo -e "${BRed}[!] FATAL: Gagal menetapkan password untuk $Login.${NC}"
            userdel -f "$Login" &>/dev/null
            exit 1
        fi
        
        DOMAIN=$(cat /root/domain 2>/dev/null || echo "IP-VPS-Anda")
        echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BGreen}    Detail Akun SSH & Dropbear    ${NC}"
        echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "Domain     : $DOMAIN"
        echo -e "Username   : $Login"
        echo -e "Password   : $Pass"
        echo -e "Port SSH   : 143, 109"
        echo -e "Port WS    : 80 (Non-TLS)"
        echo -e "Port WS/SSL: 443 (TLS)"
        echo -e "Expired    : $exp"
        echo -e "${BBlue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        ;;
    2)
        clear
        echo -e "${BRed}=== HAPUS AKUN SSH ===${NC}"
        read -p "Username yang akan dihapus : " user
        if id "$user" &>/dev/null; then
            userdel -f "$user"
            echo -e "${BGreen}Berhasil menghapus akun: $user${NC}"
        else
            echo -e "${BRed}User $user tidak ditemukan!${NC}"
        fi
        ;;
    3)
        clear
        echo -e "${BYellow}=== PERPANJANG AKUN SSH ===${NC}"
        read -p "Username : " user
        if id "$user" &>/dev/null; then
            read -p "Tambah masa aktif (Hari) : " days
            exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
            if [[ "$exp" == "never" ]]; then
                echo -e "${BRed}Akun ini bersifat lifetime (never expired).${NC}"
                exit 1
            fi
            # Konversi format
            cur_exp=$(date -d"$exp" +%Y-%m-%d)
            new_exp=$(date -d"$cur_exp + $days days" +"%Y-%m-%d")
            usermod -e "$new_exp" "$user"
            echo -e "${BGreen}Berhasil! Expired baru untuk $user adalah: $new_exp${NC}"
        else
            echo -e "${BRed}User $user tidak ditemukan!${NC}"
        fi
        ;;
    4)
        clear
        echo -e "${BBlue}=== DAFTAR USER ONLINE ===${NC}"
        echo -e "Cek koneksi pada Port Dropbear..."
        if [ -f "/var/log/auth.log" ]; then
            grep -i "dropbear" /var/log/auth.log | grep -i "Password auth succeeded" > /tmp/login-db.txt
            dropbear_pids=($(ps aux | grep -i dropbear | awk '{print $2}'))
            echo -e "PID     | USERNAME "
            echo -e "-------------------"
            for PID in "${dropbear_pids[@]}"; do
                login_info=$(grep "dropbear\[$PID\]" /tmp/login-db.txt | awk '{print $10}' | tr -d "'")
                if [ ! -z "$login_info" ]; then
                    echo -e "$PID   | $login_info"
                fi
            done
        else
            echo -e "${BRed}Log authentication tidak ditemukan di /var/log/auth.log${NC}"
        fi
        ;;
    5)
        clear
        echo -e "${BBlue}=== DAFTAR SEMUA AKUN ===${NC}"
        awk -F: '($3 >= 1000 && $1 != "nobody" && $7 == "/bin/false") {print $1}' /etc/passwd | while read line
        do
            exp=$(chage -l "$line" | grep "Account expires" | awk -F": " '{print $2}')
            echo -e "Username: ${BGreen}$line${NC} | Expired: ${BYellow}$exp${NC}"
        done
        ;;
    x|X)
        exit 0
        ;;
    *)
        echo -e "${BRed}Pilihan tidak valid!${NC}"
        ;;
esac
