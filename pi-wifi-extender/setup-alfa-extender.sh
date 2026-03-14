#!/bin/bash
# Pi Wi-Fi bridge (wlan0 -> eth0 -> Cisco) stays UNTOUCHED.
# This script only configures Alfa (wlan1) as AP extender.
# Run on Pi: sudo bash setup-alfa-extender.sh

set -e

WLAN1=wlan1
HOSTAPD_CONF=/etc/hostapd/hostapd.conf
DNSMASQ_EXTENDER=/etc/dnsmasq.d/wlan1-extender.conf

echo "=== Checking interfaces ==="
if ! ip link show "$WLAN1" &>/dev/null; then
  echo "ERROR: $WLAN1 not found. Plug in Alfa USB and run again."
  exit 1
fi
echo "OK: $WLAN1 found (Alfa). Not touching wlan0 (bridge)."

echo "=== Installing hostapd and dnsmasq ==="
sudo apt update
sudo apt install -y hostapd dnsmasq
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

echo "=== Deploying hostapd.conf for wlan1 only ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/hostapd.conf" ] && grep -q "interface=$WLAN1" "$SCRIPT_DIR/hostapd.conf"; then
  sudo cp "$SCRIPT_DIR/hostapd.conf" "$HOSTAPD_CONF"
  echo "Copied hostapd.conf from script directory to $HOSTAPD_CONF"
elif [ ! -f "$HOSTAPD_CONF" ]; then
  echo "Copy hostapd.conf to $HOSTAPD_CONF first (e.g. from this folder)."
  exit 1
fi
grep -q "interface=$WLAN1" "$HOSTAPD_CONF" || { echo "ERROR: hostapd.conf must use interface=$WLAN1"; exit 1; }

echo "=== DHCP for extender clients (wlan1 only) ==="
# Use a range that does not conflict with your bridge/Cisco subnet (e.g. 192.168.50.x for switch)
# Extender clients: 192.168.60.0/24 so bridge/switch stay untouched.
sudo tee "$DNSMASQ_EXTENDER" >/dev/null <<'EOF'
interface=wlan1
dhcp-range=192.168.60.100,192.168.60.200,12h
EOF

echo "=== IP for wlan1 (extender network) ==="
# Give wlan1 a static IP on the extender subnet
if ! grep -q "wlan1" /etc/dhcpcd.conf 2>/dev/null; then
  echo "" | sudo tee -a /etc/dhcpcd.conf
  echo "interface wlan1" | sudo tee -a /etc/dhcpcd.conf
  echo "static ip_address=192.168.60.1/24" | sudo tee -a /etc/dhcpcd.conf
  echo "nohook wpa_supplicant" | sudo tee -a /etc/dhcpcd.conf
fi

echo "=== Enable IP forwarding (only if not already) ==="
sudo sed -i 's/#*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

echo "=== NAT for wlan1 -> wlan0 (extender to internet) ==="
sudo iptables -t nat -C POSTROUTING -o wlan0 -j MASQUERADE 2>/dev/null || \
  sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -C FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -C FORWARD -i wlan1 -o wlan0 -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT

mkdir -p /etc/iptables
sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
echo "iptables rules saved to /etc/iptables/rules.v4"

echo "=== Enable and start hostapd (wlan1 only) ==="
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "=== Done. Bridge (wlan0 -> eth0 -> Cisco) is unchanged. ==="
echo "Connect devices to your extender SSID; they will use wlan0 to reach the internet."
