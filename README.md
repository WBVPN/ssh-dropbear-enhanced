# Auto Installer SSH & Dropbear Enhanced (2019.78)

Skrip *auto-installer* mandiri (stand-alone) ini dirancang khusus untuk menginstal **Dropbear SSH versi 2019.78** pada VPS Linux kosongan/fresh. Versi jadul Dropbear ini populer digunakan di industri *Tunneling* karena performa ekstraksinya (payload masking) yang lebih tangguh ketika dikombinasikan dengan Injeksi / Greentunnel.

## Fitur Utama
1. **Compile from Source**: Skrip ini TIDAK menggunakan `apt-get install dropbear` bawaan karena OS modern menggunakan versi 2020+. Skrip ini akan otomatis menyedot dan melakukan *compile* paksa kode sumber Dropbear 2019.
2. **Payload-Optimized**: Argumen *Zlib* dinonaktifkan (`--disable-zlib`) agar bypass trafik data SSH lebih lancar.
3. **Port SSH Langsung Aktif**: Otomatis mendengarkan di **Port 143 dan 109**.

## Sistem Operasi yang Didukung
- Ubuntu 20.04 / 22.04 / 24.04
- Debian 10 / 11 / 12

## Cara Instalasi

Login ke VPS Anda (sebagai `root`), lalu jalankan baris perintah berikut:

```bash
apt update -y && apt install -y curl wget && bash <(curl -s https://raw.githubusercontent.com/WBVPN/ssh-dropbear-enhanced/main/install.sh)
```

## Panduan Pengecekan
Setelah instalasi selesai, Anda dapat mengecek status aktif dari Dropbear dengan mengetik:
```bash
systemctl status dropbear
```
Untuk menguji koneksi port:
```bash
netstat -tulpn | grep dropbear
```
