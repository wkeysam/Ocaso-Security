# ~/.bashrc - Entorno Gráfico Blindado

LOGFILE="$HOME/wsl_x_display.log"
echo -e "\n\n===== [INICIO DE SESIÓN WSL] =====" | tee -a "$LOGFILE"

export HOME_SECURE=true
chmod 700 ~
set -o nounset
set -o errexit
set -o pipefail

read -p "🔐 ¿Estás en una red privada o pública?: " tipo_red
if [[ "$tipo_red" != "privada" ]]; then
  echo "🚫 Entorno gráfico bloqueado por seguridad." | tee -a "$LOGFILE"
  return 0
fi

candidatas=()
gateway_ip=$(ip route | grep default | awk '{print $3}')
[[ -n "$gateway_ip" ]] && candidatas+=("$gateway_ip")
for ip in $(hostname -I); do
  candidatas+=("$ip")
done
candidatas+=("127.0.0.1")

ip_valida=""
puerto_valido=""
for ip in "${candidatas[@]}"; do
  for display_num in {0..10}; do
    port=$((6000 + display_num))
    if timeout 1 bash -c "</dev/tcp/$ip/$port" &>/dev/null; then
      ip_valida="$ip"
      puerto_valido="$port"
      break 2
    fi
  done
done

if [[ -z "$ip_valida" || -z "$puerto_valido" ]]; then
  echo "❌ No se detectó DISPLAY válido. Revisa firewall/VcXsrv." | tee -a "$LOGFILE"
  return 1
fi

display_num=$((puerto_valido - 6000))
export DISPLAY="$ip_valida:$display_num"
echo "✅ DISPLAY configurado: $DISPLAY" | tee -a "$LOGFILE"

if command -v xclock &>/dev/null; then
  nohup xclock >/dev/null 2>&1 &
fi

trap '__logout_seguro' EXIT
function __logout_seguro() {
  echo -e "\n===== [CIERRE DE SESIÓN WSL] =====" | tee -a "$LOGFILE"
  if [[ -n "$DISPLAY" ]]; then
    ip_block=$(echo "$DISPLAY" | cut -d':' -f1)
    port_block=$((6000 + $(echo "$DISPLAY" | cut -d':' -f2)))
    powershell.exe -Command "New-NetFirewallRule -DisplayName 'WSL Block $ip_block:$port_block' -Direction Inbound -LocalPort $port_block -Protocol TCP -RemoteAddress $ip_block -Action Block"
  fi
  echo "🚪 Sesión cerrada con seguridad."
}
