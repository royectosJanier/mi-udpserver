#!/bin/bash
# ============================================
#   INSTALADOR TUNEL UDP (estilo udp-custom)
#   Para app HTTP Custom - puerto UDP configurable
# ============================================

if [ "$EUID" -ne 0 ]; then
  echo "Ejecuta como root: sudo -s"
  exit 1
fi

clear
echo "======================================"
echo "   INSTALANDO TUNEL UDP... espere"
echo "======================================"

# 1. Actualizar e instalar dependencias
apt update && apt install -y curl ufw wget

# 2. Puerto UDP del tunel (443 UDP = el mas usado para HTTP Custom)
UDP_PORT=36712
read -p "Puerto UDP para el tunel [36712]: " input
UDP_PORT=${input:-36712}

# 3. Firewall: SSH + puerto UDP del tunel
ufw allow 22/tcp
ufw allow $UDP_PORT/udp
ufw --force enable

# 4. Descargar binario udp-custom
mkdir -p /root/udp
wget -q "https://raw.github.com/http-custom/udp-custom/main/bin/udp-custom-linux-amd64" -O /root/udp/udp-custom
chmod +x /root/udp/udp-custom

# 5. Configuracion
cat > /root/udp/config.json << UDPEOF
{
  "listen": ":$UDP_PORT",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080
}
UDPEOF

# 6. Servicio systemd (arranca solo con el VPS)
cat > /etc/systemd/system/udp-custom.service << SVCEOF
[Unit]
Description=UDP Custom Tunnel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom

# 7. Gestor de usuarios con dias de uso
cat > /usr/bin/udpmenu << 'MENUEOF'
#!/bin/bash
while true; do
  clear
  echo "====== GESTION USUARIOS UDP ======"
  echo "1) Crear usuario (con dias)"
  echo "2) Listar usuarios"
  echo "3) Eliminar usuario"
  echo "4) Estado del tunel"
  echo "5) Salir"
  read -p "Elige: " op
  case $op in
    1)
      read -p "Usuario: " u
      read -p "Dias de uso: " d
      read -p "Clave (Enter = aleatoria): " p
      [ -z "$p" ] && p=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)
      useradd -m -s /bin/false -e $(date -d "+$d days" +%Y-%m-%d) "$u" 2>/dev/null
      echo "$u:$p" | chpasswd
      clear
      echo "===== CUENTA UDP CREADA ====="
      echo "IP:      $(curl -s ifconfig.me)"
      echo "Puerto:  $(grep -o '"listen": *":[0-9]*"' /root/udp/config.json | grep -o '[0-9]*')"
      echo "Formato: IP:PUERTO@$u:$p"
      echo "Expira:  $(date -d "+$d days" +%Y-%m-%d)"
      read -p "Presiona Enter..." ;;
    2)
      echo "Usuario | Expira"
      for user in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
        exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        [ -z "$exp" ] || [ "$exp" = "never" ] && exp="nunca"
        echo "$user | $exp"
      done
      read -p "Presiona Enter..." ;;
    3)
      read -p "Usuario a eliminar: " u
      userdel -r "$u" 2>/dev/null && echo "Eliminado" || echo "No existe"
      read -p "Presiona Enter..." ;;
    4)
      systemctl status udp-custom --no-pager | head -12
      read -p "Presiona Enter..." ;;
    5) exit 0 ;;
  esac
done
MENUEOF
chmod +x /usr/bin/udpmenu

clear
echo "======================================"
echo "   TUNEL UDP INSTALADO ✔"
echo "======================================"
echo "IP publica : $(curl -s ifconfig.me)"
echo "Puerto UDP : $UDP_PORT"
echo ""
echo "GESTION DE USUARIOS:"
echo "  udpmenu"
echo ""
echo "Para clientes (app HTTP Custom):"
echo "  IP:$UDP_PORT@usuario:clave"
echo "======================================"
