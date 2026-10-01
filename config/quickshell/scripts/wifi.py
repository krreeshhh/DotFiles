#!/usr/bin/env python3
import sys
import subprocess
import json

def get_saved_connections():
    try:
        res = subprocess.run(['nmcli', '-g', 'NAME,TYPE', 'con', 'show'], capture_output=True, text=True, timeout=5)
        saved = set()
        for line in res.stdout.strip().splitlines():
            if not line:
                continue
            parts = line.split(':')
            if len(parts) >= 2 and parts[1] == '802-11-wireless':
                saved.add(parts[0])
        return saved
    except Exception:
        return set()

def get_wifi_device():
    try:
        res = subprocess.run(['nmcli', '-g', 'DEVICE,TYPE', 'dev'], capture_output=True, text=True, timeout=5)
        for line in res.stdout.strip().splitlines():
            parts = line.split(':')
            if len(parts) >= 2 and parts[1] == 'wifi':
                return parts[0]
    except Exception:
        pass
    return 'wlan0'

def parse_nmcli_line(line):
    # Splits fields by colon, respecting backslash escaping '\:'
    parts = []
    cur = []
    escaped = False
    for ch in line:
        if escaped:
            cur.append(ch)
            escaped = False
        elif ch == '\\':
            escaped = True
        elif ch == ':':
            parts.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append(''.join(cur))
    return parts

def list_networks(rescan=False):
    # Check if wifi radio is enabled
    try:
        radio = subprocess.run(['nmcli', 'radio', 'wifi'], capture_output=True, text=True, timeout=5)
        if radio.stdout.strip() == 'disabled':
            return []
    except Exception:
        pass

    saved = get_saved_connections()
    cmd = ['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list']
    if rescan:
        cmd.extend(['--rescan', 'yes'])
    else:
        cmd.extend(['--rescan', 'no'])

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
    except Exception:
        return []

    networks = {}
    for line in res.stdout.strip().splitlines():
        if not line:
            continue
        parts = parse_nmcli_line(line)
        if len(parts) >= 4:
            in_use = ('*' in parts[0])
            ssid = parts[1]
            try:
                sig = int(parts[2])
            except ValueError:
                sig = 0
            sec = parts[3].strip()
            if sec == '--':
                sec = ''

            if not ssid or ssid == '--':
                continue

            is_saved = (ssid in saved)

            if ssid not in networks:
                networks[ssid] = {
                    'ssid': ssid,
                    'signal': sig,
                    'security': sec,
                    'inUse': in_use,
                    'isSaved': is_saved
                }
            else:
                if in_use:
                    networks[ssid]['inUse'] = True
                if is_saved:
                    networks[ssid]['isSaved'] = True
                if sig > networks[ssid]['signal']:
                    networks[ssid]['signal'] = sig

    net_list = list(networks.values())
    # Sort order: 1. Connected first, 2. Saved networks, 3. Signal descending
    net_list.sort(key=lambda x: (not x['inUse'], not x['isSaved'], -x['signal']))
    return net_list

def get_status():
    try:
        radio = subprocess.run(['nmcli', 'radio', 'wifi'], capture_output=True, text=True, timeout=3)
        if radio.stdout.strip() == 'disabled':
            return 'disabled'

        p = subprocess.run(['nmcli', '-t', '-f', 'IN-USE,SIGNAL', 'dev', 'wifi', 'list', '--rescan', 'no'], capture_output=True, text=True, timeout=5)
        for line in p.stdout.strip().splitlines():
            if line.startswith('*:'):
                parts = line.split(':')
                if len(parts) >= 2:
                    return f"connected:{parts[1]}"
                return "connected:100"
        return 'disconnected'
    except Exception:
        return 'disconnected'

def connect_network(ssid, password=None):
    if not ssid:
        return {'success': False, 'error': 'No SSID provided'}

    previously_saved = (ssid in get_saved_connections())

    if password and len(password.strip()) > 0:
        cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid, 'password', password]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
            if p.returncode != 0:
                err = (p.stderr or p.stdout or '').strip()
                # Clean up newly generated corrupt/failed connection profile if not previously saved
                if not previously_saved:
                    subprocess.run(['nmcli', 'con', 'delete', 'id', ssid], capture_output=True)

                msg = 'Connection failed.'
                if 'Secrets were required' in err or 'password' in err.lower() or 'authentication' in err.lower() or 'psk' in err.lower():
                    msg = 'Incorrect password. Please try again.'
                elif 'No network with SSID' in err:
                    msg = 'Network not found or out of range.'
                elif 'timeout' in err.lower():
                    msg = 'Connection timed out. Check password or router.'
                else:
                    for line in err.splitlines():
                        if 'Error:' in line:
                            msg = line.replace('Error:', '').strip()
                            break
                return {'success': False, 'error': msg}
            return {'success': True}
        except subprocess.TimeoutExpired:
            if not previously_saved:
                subprocess.run(['nmcli', 'con', 'delete', 'id', ssid], capture_output=True)
            return {'success': False, 'error': 'Connection timed out.'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    else:
        # Connect to saved or open network without password
        # First try activating saved profile by connection ID
        try:
            p = subprocess.run(['nmcli', 'con', 'up', 'id', ssid], capture_output=True, text=True, timeout=20)
            if p.returncode == 0:
                return {'success': True}
        except Exception:
            pass

        # Fallback to dev wifi connect (works for open networks or saved credentials)
        try:
            p2 = subprocess.run(['nmcli', 'dev', 'wifi', 'connect', ssid], capture_output=True, text=True, timeout=25)
            if p2.returncode == 0:
                return {'success': True}

            err = (p2.stderr or p2.stdout or '').strip()
            msg = 'Failed to connect.'
            if 'Secrets were required' in err or 'password' in err.lower():
                msg = 'Password required or saved credentials invalid.'
            elif 'No network with SSID' in err:
                msg = 'Network not found or out of range.'
            else:
                for line in err.splitlines():
                    if 'Error:' in line:
                        msg = line.replace('Error:', '').strip()
                        break
            return {'success': False, 'error': msg}
        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Connection timed out.'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

def disconnect_network(ssid):
    # Try disconnecting connection by ID first
    if ssid:
        try:
            subprocess.run(['nmcli', 'con', 'down', 'id', ssid], capture_output=True, timeout=8)
        except Exception:
            pass

    # Ensure device is disconnected
    dev = get_wifi_device()
    try:
        subprocess.run(['nmcli', 'dev', 'disconnect', dev], capture_output=True, timeout=8)
    except Exception:
        pass

    return {'success': True}

def forget_network(ssid):
    if not ssid:
        return {'success': False, 'error': 'No SSID provided'}
    try:
        p = subprocess.run(['nmcli', 'con', 'delete', 'id', ssid], capture_output=True, text=True, timeout=8)
        if p.returncode == 0:
            return {'success': True}
        return {'success': False, 'error': p.stderr.strip() or 'Failed to delete connection profile.'}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def main():
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'No action specified'}))
        sys.exit(1)

    action = sys.argv[1]

    if action == 'list':
        rescan = ('--rescan' in sys.argv)
        nets = list_networks(rescan=rescan)
        print(json.dumps(nets))

    elif action == 'saved':
        saved = list(get_saved_connections())
        print(json.dumps(saved))

    elif action == 'status':
        print(get_status())

    elif action == 'connect':
        if len(sys.argv) < 3:
            print(json.dumps({'success': False, 'error': 'Missing SSID'}))
            sys.exit(1)
        ssid = sys.argv[2]
        password = sys.argv[3] if len(sys.argv) > 3 else None
        res = connect_network(ssid, password)
        print(json.dumps(res))

    elif action == 'disconnect':
        ssid = sys.argv[2] if len(sys.argv) > 2 else ''
        res = disconnect_network(ssid)
        print(json.dumps(res))

    elif action == 'forget':
        if len(sys.argv) < 3:
            print(json.dumps({'success': False, 'error': 'Missing SSID'}))
            sys.exit(1)
        ssid = sys.argv[2]
        res = forget_network(ssid)
        print(json.dumps(res))

    else:
        print(json.dumps({'error': f"Unknown action: {action}"}))
        sys.exit(1)

if __name__ == '__main__':
    main()
