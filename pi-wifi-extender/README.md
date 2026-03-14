# Pi Wi-Fi Bridge + Alfa Extender Setup

Your Pi stays **Wi-Fi → Ethernet bridge** (wlan0 → eth0 → Cisco switch). This adds the **Alfa USB (wlan1)** as a Wi-Fi extender in your room **without touching the bridge**.

## Interface roles

| Interface | Role |
|-----------|------|
| **wlan0** | Connected to main router Wi-Fi — **bridge to Cisco (do not change)** |
| **eth0** | Bridge to Cisco switch |
| **wlan1** (Alfa USB) | AP / extender — devices in your room connect here |

## Quick steps on the Pi

1. **Copy files to the Pi** (from this folder):
   - `hostapd.conf` → `/etc/hostapd/hostapd.conf`
   - `setup-alfa-extender.sh` → e.g. `~/setup-alfa-extender.sh`

2. **Edit the extender SSID/password** (optional):
   ```bash
   sudo nano /etc/hostapd/hostapd.conf
   ```
   Change `ssid=MyHomeExtender` and `wpa_passphrase=StrongPassword123` to your values.

3. **Run the setup script** (from the folder that contains the script):
   ```bash
   chmod +x setup-alfa-extender.sh
   sudo bash setup-alfa-extender.sh
   ```
   If you get "No such file or directory" when using `./setup-alfa-extender.sh`, the file has Windows line endings. Use `sudo bash setup-alfa-extender.sh` instead, or fix with: `sed -i 's/\r$//' setup-alfa-extender.sh`

4. **If `hostapd.conf` was missing**, create it first:
   ```bash
   sudo nano /etc/hostapd/hostapd.conf
   ```
   Paste the contents of `hostapd.conf` from this folder (interface must be `wlan1`).

## Safety (bridge will not be cut off)

- **hostapd** is configured for **wlan1 only**. wlan0 is never used for AP.
- **dnsmasq** for the extender only serves **wlan1** (e.g. 192.168.60.x) so it does not conflict with your Cisco/bridge subnet.
- **NAT/forwarding** sends extender traffic (wlan1) out via wlan0; the existing bridge (wlan0 ↔ eth0) is left as-is.

## After setup

- Devices in your room connect to the extender SSID (e.g. `MyHomeExtender`).
- They get IPs from the Pi (192.168.60.x) and internet via wlan0 → main router.
- The Cisco switch and all bridge behaviour stay unchanged.

## Restore iptables after reboot (optional)

If your Pi doesn’t load iptables rules on boot, install:

```bash
sudo apt install iptables-persistent
```

During install, choose to save current rules. The script already writes `/etc/iptables/rules.v4`; `iptables-persistent` will load it at boot.
