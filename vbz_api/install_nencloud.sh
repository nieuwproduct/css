#!/bin/bash

#=============================================================================
# Nencloud Client Installation Script for Debian/Ubuntu (FIXED VERSION)
#=============================================================================
# This script will:
# 1. Install Python and required dependencies (using apt for Python packages)
# 2. Download and install the Nencloud client files
# 3. Configure the client with interactive prompts
# 4. Install and start a systemd daemon service
# 5. Set up proper permissions and directories
#=============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/nencloud"
CONFIG_DIR="/etc/nencloud"
LOG_DIR="/var/log/nencloud"
SERVICE_NAME="nencloud-client"
USER_NAME="developer"
SCRIPT_VERSION="1.5.6"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if installation exists
check_installation() {
    if [[ -d "$INSTALL_DIR" ]] || [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        return 0
    else
        return 1
    fi
}

# Get current version
get_current_version() {
    if [[ -f "$INSTALL_DIR/version.txt" ]]; then
        cat "$INSTALL_DIR/version.txt"
    else
        echo "unknown"
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    print_info "Detected OS: $OS $OS_VERSION"
}

# Install system dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    # Update package list
    apt-get update -qq
    
    # Install Python and dependencies (including python3-requests via apt)
    apt-get install -y \
        python3 \
        python3-requests \
        python3-venv \
        curl \
        systemd \
        cron \
        logrotate \
        wget
    
    # Create symlink for python if it doesn't exist
    if ! command -v python &> /dev/null; then
        ln -sf /usr/bin/python3 /usr/bin/python
    fi
    
    print_success "System dependencies installed"
}

# Verify developer user exists
verify_user() {
    if ! id "$USER_NAME" &>/dev/null; then
        print_error "User $USER_NAME does not exist. Please create the developer user first or run this script on a system where the developer user exists."
        exit 1
    else
        print_info "Using existing user: $USER_NAME"
    fi
}

# Create directories
create_directories() {
    print_info "Creating directories..."
    
    mkdir -p $INSTALL_DIR
    mkdir -p $CONFIG_DIR
    mkdir -p $LOG_DIR
    mkdir -p /etc/systemd/system
    
    # Set permissions
    chown -R $USER_NAME:$USER_NAME $INSTALL_DIR
    chown -R $USER_NAME:$USER_NAME $CONFIG_DIR
    chown -R $USER_NAME:$USER_NAME $LOG_DIR
    
    print_success "Directories created and permissions set"
}

# Download client files
download_client_files() {
    print_info "Downloading Nencloud client files..."
    
    cat > $INSTALL_DIR/nencloud_client.py << 'EOF'
#!/usr/bin/env python3
"""
Nencloud Configuration Client
A client for fetching and synchronizing configuration from the Nencloud server.
"""

import argparse
import json
import os
import sys
import hashlib
import tempfile
import shutil
from pathlib import Path
import requests
from typing import Dict, Any, Optional, List
import time
import re
import subprocess


class GPIOMonitor:
    """Monitor GPIO status from debugfs."""
    
    def __init__(self):
        self.gpio_reader_script = '/opt/nencloud/read_gpio.sh'
        self.chip_name = 'gpio-f81964-0'
    
    def read_gpio_status(self) -> Optional[List[Dict[str, Any]]]:
        """Read and parse GPIO status from debugfs using sudo wrapper."""
        try:
            # Run the GPIO reader script with sudo
            result = subprocess.run(
                ['sudo', self.gpio_reader_script],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                print(f"GPIO reader script failed: {result.stderr}")
                return None
            
            content = result.stdout
            
            if not content or 'ERROR' in content:
                return None
            
            # Parse GPIO lines (content is already the gpio-f81964-0 section)
            return self._parse_gpio_lines(content)
            
        except subprocess.TimeoutExpired:
            print("GPIO read timeout")
            return None
        except Exception as e:
            print(f"Error reading GPIO status: {e}")
            return None
    
    def _parse_gpio_lines(self, section: str) -> List[Dict[str, Any]]:
        """Parse GPIO lines into structured data."""
        gpio_pins = []
        lines = section.split('\n')
        
        for line in lines:
            # Skip header line
            if self.chip_name in line or not line.strip():
                continue
            
            # Parse GPIO line format: " gpio-480 (                    |sysfs               ) in  hi"
            # or: " gpio-480 (                    |GPIO0               ) out lo"
            match = re.search(r'gpio-(\d+)\s+\([^|]*\|([^)]*)\)\s+(in|out)\s+(hi|lo)', line)
            
            if match:
                pin_number = int(match.group(1))
                label = match.group(2).strip() or f"GPIO{pin_number}"
                direction = match.group(3)
                value = match.group(4)
                
                gpio_pins.append({
                    'pin': pin_number,
                    'label': label,
                    'direction': direction,
                    'value': value
                })
        
        return gpio_pins


class NencloudClient:
    def __init__(self, server_url: str, auth_token: str, api_username: str, location_id: Optional[int] = None):
        self.server_url = server_url.rstrip('/')
        self.auth_token = auth_token
        self.api_username = api_username
        self.location_id = location_id
        self.timeout = 30
        
    def test_connection(self) -> bool:
        """Test connection to server."""
        try:
            # Use location-specific endpoint if location_id is provided
            if self.location_id:
                url = f"{self.server_url}/api/config/{self.location_id}/"
            else:
                url = f"{self.server_url}/api/config/"
            
            headers = {
                'Authorization': f'Token {self.auth_token}',
                'Content-Type': 'application/json'
            }
            
            # Only add X-API-Username header if we have a location_id
            if self.location_id:
                headers['X-API-Username'] = self.api_username
            
            print(f"Testing connection to: {url}")
            response = requests.get(url, headers=headers, timeout=self.timeout)
            
            if response.status_code == 200:
                print("✓ Connection test successful")
                return True
            else:
                print(f"✗ Connection test failed: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            print(f"✗ Connection test failed: {e}")
            return False
        
    def get_config(self) -> Dict[str, Any]:
        """Fetch configuration from server (returns config for daemon use)."""
        if self.location_id:
            url = f"{self.server_url}/api/config/{self.location_id}/"
        else:
            url = f"{self.server_url}/api/config/"
            
        headers = {
            'Authorization': f'Token {self.auth_token}',
            'X-API-Username': self.api_username,
            'Content-Type': 'application/json'
        }
        
        print(f"Fetching configuration from: {url}")
        
        try:
            response = requests.get(url, headers=headers, timeout=self.timeout)
            response.raise_for_status()
            
            data = response.json()
            print(f"✓ Successfully fetched configuration ({len(response.content)} bytes)")
            
            # API returns the config directly (NOT wrapped in merged_config)
            # Validate that we got actual config data
            if not data or not isinstance(data, dict):
                raise ValueError(f"Invalid config response: {type(data)}")
            
            # Check if it's actually empty (which would corrupt the file)
            if data == {}:
                raise ValueError("Server returned empty config - refusing to save")
            
            return data
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to fetch configuration: {e}")
            raise
    
    def send_gpio_status(self, gpio_data: List[Dict[str, Any]]) -> bool:
        """Send GPIO status to server."""
        if not self.location_id:
            return False  # GPIO status only for location-specific clients
        
        url = f"{self.server_url}/api/gpio-status/{self.location_id}/"
        
        headers = {
            'Authorization': f'Token {self.auth_token}',
            'X-API-Username': self.api_username,
            'Content-Type': 'application/json'
        }
        
        try:
            response = requests.post(
                url, 
                headers=headers, 
                json={'gpio_data': gpio_data},
                timeout=self.timeout
            )
            response.raise_for_status()
            return True
            
        except requests.exceptions.RequestException as e:
            print(f"Warning: Failed to send GPIO status: {e}")
            return False


class ConfigSyncer:
    def __init__(self, local_config_path: str, backup_dir: Optional[str] = None):
        self.local_config_path = local_config_path
        self.backup_dir = backup_dir or os.path.join(os.path.dirname(local_config_path), 'backups')
        
    def calculate_config_hash(self, config_data: Dict[str, Any]) -> str:
        """Calculate MD5 hash of configuration for change detection."""
        config_json = json.dumps(config_data, sort_keys=True, separators=(',', ':'))
        return hashlib.md5(config_json.encode('utf-8')).hexdigest()
    
    def needs_sync(self, server_config: Dict[str, Any]) -> bool:
        """Check if local configuration needs updating."""
        try:
            if not os.path.exists(self.local_config_path):
                return True
                
            with open(self.local_config_path, 'r', encoding='utf-8') as f:
                local_config = json.load(f)
            
            local_hash = self.calculate_config_hash(local_config)
            server_hash = self.calculate_config_hash(server_config)
            
            return local_hash != server_hash
            
        except Exception as e:
            print(f"Error checking sync status: {e}")
            return True
    
    def save_config(self, config: Dict[str, Any], create_backup: bool = True) -> bool:
        """Save configuration with atomic write and optional backup."""
        try:
            config_path = Path(self.local_config_path)
            
            # Create backup if requested and file exists
            if create_backup and config_path.exists():
                backup_dir = Path(self.backup_dir)
                backup_dir.mkdir(parents=True, exist_ok=True)
                backup_name = f"appsettings.json.backup.{int(time.time())}"
                backup_path = backup_dir / backup_name
                shutil.copy2(config_path, backup_path)
                print(f"✓ Backup created: {backup_path}")
            
            # Ensure directory exists
            config_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write to temporary file first (atomic operation)
            with tempfile.NamedTemporaryFile(
                mode='w', 
                encoding='utf-8',
                dir=config_path.parent,
                delete=False,
                suffix='.tmp'
            ) as tmp_file:
                json.dump(config, tmp_file, indent=2, sort_keys=True)
                tmp_file.flush()
                os.fsync(tmp_file.fileno())
                temp_path = tmp_file.name
            
            # Atomic move
            shutil.move(temp_path, config_path)
            
            print(f"✓ Configuration saved to: {config_path}")
            return True
            
        except Exception as e:
            print(f"✗ Failed to save configuration: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description='Nencloud Configuration Client')
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--server', help='Server URL')
    parser.add_argument('--token', help='Authentication token')
    parser.add_argument('--location-id', type=int, help='Location ID')
    parser.add_argument('--output', help='Output file path')
    parser.add_argument('--config-dir', help='Configuration directory')
    parser.add_argument('--sync', action='store_true', help='Sync with change detection')
    parser.add_argument('--force', action='store_true', help='Force sync even without changes')
    parser.add_argument('--test', action='store_true', help='Test connection')
    
    args = parser.parse_args()
    
    # Load configuration
    if args.config:
        try:
            with open(args.config, 'r') as f:
                config = json.load(f)
            server_url = config.get('server_url')
            auth_token = config.get('auth_token')
            api_username = config.get('api_username')
            location_id = config.get('location_id')
            
            if args.config_dir:
                local_config_path = os.path.join(args.config_dir, 'appsettings.json')
            else:
                local_config_path = config.get('local_config_path', 'appsettings.json')
                
        except Exception as e:
            print(f"✗ Failed to load config file: {e}")
            sys.exit(1)
    else:
        server_url = args.server
        auth_token = args.token
        location_id = args.location_id
        
        if args.config_dir:
            local_config_path = os.path.join(args.config_dir, 'appsettings.json')
        else:
            local_config_path = args.output or 'appsettings.json'
    
    # Validate required parameters
    if not server_url or not auth_token or not api_username:
        print("✗ Error: server_url, auth_token, and api_username are required")
        sys.exit(1)
    
    # Initialize client
    try:
        client = NencloudClient(server_url, auth_token, api_username, location_id)
        
        if args.test:
            # Test connection only
            if client.test_connection():
                print("✓ Connection test passed")
                sys.exit(0)
            else:
                print("✗ Connection test failed")
                sys.exit(1)
        elif args.sync:
            syncer = ConfigSyncer(local_config_path)
            server_config = client.get_config()
            
            if args.force or syncer.needs_sync(server_config):
                if syncer.save_config(server_config):
                    print("✓ Configuration synchronized successfully")
                else:
                    sys.exit(1)
            else:
                print("✓ Local configuration is already up to date")
        else:
            # Simple fetch and save
            config = client.get_config()
            syncer = ConfigSyncer(local_config_path)
            if syncer.save_config(config, create_backup=False):
                print(f"✓ Configuration saved to: {local_config_path}")
            else:
                sys.exit(1)
                
    except KeyboardInterrupt:
        print("\n✗ Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Operation failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
EOF

    # Make executable
    chmod +x $INSTALL_DIR/nencloud_client.py
    
    # Create version file
    echo "$SCRIPT_VERSION" > $INSTALL_DIR/version.txt
    chown $USER_NAME:$USER_NAME $INSTALL_DIR/version.txt
    
    print_success "Client files downloaded and installed"
}

# Check location availability
check_location_availability() {
    local server_url="$1"
    local auth_token="$2"
    local location_id="$3"
    
    if [[ -z "$location_id" ]]; then
        return 0  # Global config, no need to check
    fi
    
    print_info "Checking location availability..."
    
    # Test connection and check location availability
    local url="${server_url}/api/locations/${location_id}/availability/"
    local headers=(
        -H "Authorization: Token ${auth_token}"
        -H "Content-Type: application/json"
    )
    
    local response
    if response=$(curl -s -w "\n%{http_code}" "${headers[@]}" "$url" 2>/dev/null); then
        local http_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | head -n -1)
        
        if [[ "$http_code" == "200" ]]; then
            local available=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('available', False))" 2>/dev/null)
            local message=$(echo "$body" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', ''))" 2>/dev/null)
            
            if [[ "$available" == "True" ]]; then
                print_success "Location is available: $message"
                return 0
            else
                print_error "Location is not available: $message"
                return 1
            fi
        else
            print_warning "Could not check location availability (HTTP $http_code). Proceeding anyway..."
            return 0
        fi
    else
        print_warning "Could not check location availability. Proceeding anyway..."
        return 0
    fi
}

# Interactive configuration
configure_client() {
    print_info "Setting up Nencloud client configuration..."
    
    echo
    echo "Please provide the following information:"
    echo
    
    # Server URL - fixed value
    SERVER_URL="https://nencloud.vanbreda.nl"
    print_info "Using server URL: $SERVER_URL"
    
    # Authentication token
    read -p "Enter authentication token: " AUTH_TOKEN
    if [[ -z "$AUTH_TOKEN" ]]; then
        print_error "Authentication token is required"
        exit 1
    fi
    
    # API Username
    read -p "Enter API username: " API_USERNAME
    if [[ -z "$API_USERNAME" ]]; then
        print_error "API username is required"
        exit 1
    fi
    
    # Location ID
    read -p "Enter location ID (or press Enter for global config): " LOCATION_ID
    
    # Check location availability if location ID is provided
    if [[ -n "$LOCATION_ID" ]]; then
        if ! check_location_availability "$SERVER_URL" "$AUTH_TOKEN" "$LOCATION_ID"; then
            print_error "Cannot proceed with installation. Location is not available for new client connections."
            print_info "Please check the admin panel to enable 'Allow Multiple Clients' for this location, or disconnect any existing clients."
            exit 1
        fi
    fi
    
    # Config directory - fixed value
    APP_CONFIG_DIR="/etc/nencloud"
    print_info "Using config directory: $APP_CONFIG_DIR"
    
    # Sync interval
    read -p "Enter sync interval in minutes [1]: " SYNC_INTERVAL
    SYNC_INTERVAL=${SYNC_INTERVAL:-1}
    
    # GPIO status interval
    read -p "Enter GPIO status reporting interval in seconds [5]: " GPIO_INTERVAL
    GPIO_INTERVAL=${GPIO_INTERVAL:-5}
    
    # Create config file
    cat > $CONFIG_DIR/client.json << EOF
{
  "server_url": "$SERVER_URL",
  "auth_token": "$AUTH_TOKEN",
  "api_username": "$API_USERNAME",
  "location_id": ${LOCATION_ID:-null},
  "local_config_path": "$APP_CONFIG_DIR/appsettings.json",
  "config_directory": "$APP_CONFIG_DIR",
  "backup_dir": "$APP_CONFIG_DIR/backups",
  "sync_interval_minutes": $SYNC_INTERVAL,
  "gpio_status_interval_seconds": $GPIO_INTERVAL,
  "timeout_seconds": 30
}
EOF
    
    # Set permissions
    chown $USER_NAME:$USER_NAME $CONFIG_DIR/client.json
    chmod 600 $CONFIG_DIR/client.json
    
    # Create app config directory
    mkdir -p $APP_CONFIG_DIR
    mkdir -p $APP_CONFIG_DIR/backups
    chown -R $USER_NAME:$USER_NAME $APP_CONFIG_DIR
    
    print_success "Configuration created: $CONFIG_DIR/client.json"
}

# Create daemon script
create_daemon() {
    print_info "Creating daemon script..."
    
    cat > $INSTALL_DIR/nencloud_daemon.py << 'EOF'
#!/usr/bin/env python3
"""
Nencloud Configuration Daemon
Continuously synchronizes configuration from Nencloud server.
"""

import json
import os
import sys
import time
import signal
import logging
import threading
from pathlib import Path

# Add the install directory to Python path
sys.path.insert(0, '/opt/nencloud')
from nencloud_client import NencloudClient, ConfigSyncer, GPIOMonitor


class NencloudDaemon:
    def __init__(self, config_path: str):
        self.config_path = config_path
        self.running = False
        self.gpio_thread = None
        self.setup_logging()
        self.load_config()
        
    def setup_logging(self):
        """Setup logging configuration."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/nencloud/daemon.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('nencloud-daemon')
        
    def load_config(self):
        """Load configuration from file."""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            
            self.server_url = config['server_url']
            self.auth_token = config['auth_token']
            self.api_username = config['api_username']
            self.location_id = config.get('location_id')
            self.local_config_path = config.get('local_config_path', '/etc/app/appsettings.json')
            self.sync_interval = config.get('sync_interval_minutes', 60) * 60
            self.backup_dir = config.get('backup_dir')
            
            self.client = NencloudClient(self.server_url, self.auth_token, self.api_username, self.location_id)
            self.syncer = ConfigSyncer(self.local_config_path, self.backup_dir)
            self.gpio_monitor = GPIOMonitor() if self.location_id else None
            self.gpio_interval = config.get('gpio_status_interval_seconds', 5)
            
            self.logger.info(f"Configuration loaded: {self.config_path}")
            self.logger.info(f"Server: {self.server_url}")
            self.logger.info(f"Location: {self.location_id or 'Global'}")
            self.logger.info(f"Sync interval: {self.sync_interval} seconds")
            if self.gpio_monitor:
                self.logger.info(f"GPIO monitoring: enabled (interval: {self.gpio_interval}s)")
            
        except Exception as e:
            self.logger.error(f"Failed to load configuration: {e}")
            sys.exit(1)
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
    
    def sync_config(self):
        """Perform configuration sync."""
        try:
            server_config = self.client.get_config()
            
            if self.syncer.needs_sync(server_config):
                if self.syncer.save_config(server_config):
                    self.logger.info("Configuration synchronized successfully - changes detected")
                    # Restart nencloud service after successful config sync
                    self.restart_nencloud_service()
                else:
                    self.logger.error("Failed to save configuration")
            else:
                self.logger.debug("Configuration is up to date - no changes, file not modified")
                
        except Exception as e:
            self.logger.error(f"Sync failed: {e}")
    
    def restart_nencloud_service(self):
        """Restart the nencloud service after configuration changes."""
        import subprocess
    
        try:
            result = subprocess.run(
                ['systemctl', 'restart', 'nencloud'],
                capture_output=True,
                text=True,
                timeout=60
            )
            if result.returncode == 0:
                self.logger.info("Successfully restarted nencloud service")
            else:
                self.logger.error(f"Failed to restart nencloud service: {result.stderr.strip()}")
        except subprocess.TimeoutExpired:
            self.logger.error("Timeout while restarting nencloud service")
        except Exception as e:
            self.logger.error(f"Error restarting nencloud service: {e}")
    
    def gpio_monitoring_loop(self):
        """Separate thread for GPIO status monitoring and reporting."""
        self.logger.info("Starting GPIO monitoring thread...")
        
        while self.running:
            try:
                # Read GPIO status
                gpio_data = self.gpio_monitor.read_gpio_status()
                
                if gpio_data:
                    # Send to server
                    success = self.client.send_gpio_status(gpio_data)
                    if success:
                        self.logger.debug(f"GPIO status sent: {len(gpio_data)} pins")
                    else:
                        self.logger.warning("Failed to send GPIO status")
                else:
                    self.logger.debug("No GPIO data available")
                
            except Exception as e:
                self.logger.error(f"GPIO monitoring error: {e}")
            
            # Wait for next interval
            time.sleep(self.gpio_interval)
        
        self.logger.info("GPIO monitoring thread stopped")
    
    
    def run(self):
        """Main daemon loop."""
        self.logger.info("Starting Nencloud daemon...")
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        self.running = True
        
        # Start GPIO monitoring thread if location-specific
        if self.gpio_monitor:
            self.gpio_thread = threading.Thread(target=self.gpio_monitoring_loop, daemon=True)
            self.gpio_thread.start()
            self.logger.info("GPIO monitoring thread started")
        
        # Initial sync
        self.sync_config()
        
        # Main loop
        while self.running:
            try:
                time.sleep(self.sync_interval)
                if self.running:
                    self.sync_config()
            except Exception as e:
                self.logger.error(f"Daemon error: {e}")
                time.sleep(60)  # Wait a minute before retrying
        
        # Wait for GPIO thread to finish
        if self.gpio_thread and self.gpio_thread.is_alive():
            self.gpio_thread.join(timeout=5)
        
        self.logger.info("Daemon stopped")


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else '/etc/nencloud/client.json'
    daemon = NencloudDaemon(config_path)
    daemon.run()


if __name__ == '__main__':
    main()
EOF

    chmod +x $INSTALL_DIR/nencloud_daemon.py
    chown $USER_NAME:$USER_NAME $INSTALL_DIR/nencloud_daemon.py
    
    print_success "Daemon script created"
}

# Setup debugfs mount and GPIO access
setup_debugfs() {
    print_info "Setting up debugfs for GPIO monitoring..."
    
    # Mount debugfs
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
    
    # Add to fstab for automatic mounting
    if ! grep -q "debugfs.*\/sys\/kernel\/debug" /etc/fstab 2>/dev/null; then
        echo "debugfs /sys/kernel/debug debugfs defaults 0 0" >> /etc/fstab
        print_info "Added debugfs to /etc/fstab"
    fi
    
    # Create GPIO reader wrapper script that runs with sudo
    cat > $INSTALL_DIR/read_gpio.sh << 'GPIOEOF'
#!/bin/bash
# GPIO reader wrapper script
# Mounts debugfs if needed and reads GPIO status
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
if [ -f "/sys/kernel/debug/gpio" ]; then
    sed -n '/gpio-f81964-0/,/^$/p' /sys/kernel/debug/gpio
else
    echo "ERROR: GPIO debugfs not available"
    exit 1
fi
GPIOEOF
    
    chmod +x $INSTALL_DIR/read_gpio.sh
    chown root:root $INSTALL_DIR/read_gpio.sh
    
    # Add sudoers rule to allow developer user to run GPIO reader without password
    cat > /etc/sudoers.d/nencloud-gpio << 'SUDOEOF'
# Allow developer user to read GPIO status without password
developer ALL=(root) NOPASSWD: /opt/nencloud/read_gpio.sh
SUDOEOF
    
    chmod 440 /etc/sudoers.d/nencloud-gpio
    
    # Validate sudoers file
    visudo -c -f /etc/sudoers.d/nencloud-gpio
    if [ $? -eq 0 ]; then
        print_success "Sudoers rule created for GPIO access"
    else
        print_error "Failed to create sudoers rule"
        rm -f /etc/sudoers.d/nencloud-gpio
    fi
    
    # Test GPIO access as developer user
    if sudo -u $USER_NAME sudo $INSTALL_DIR/read_gpio.sh > /dev/null 2>&1; then
        print_success "GPIO access verified for $USER_NAME user"
    else
        print_warning "Could not verify GPIO access. GPIO monitoring may not work."
    fi
    
    print_success "debugfs and GPIO access configured"
}

# Create systemd service
create_service() {
    print_info "Creating systemd service..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Nencloud Configuration Client Daemon
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/nencloud_daemon.py $CONFIG_DIR/client.json
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
# Note: NoNewPrivileges must be false to allow GPIO access via sudo
NoNewPrivileges=false
PrivateTmp=false
ProtectSystem=false
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    
    print_success "Systemd service created and enabled"
}

# Setup log rotation
setup_logging() {
    print_info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/nencloud << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER_NAME $USER_NAME
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF

    print_success "Log rotation configured"
}

# Setup polkit for service restart
setup_polkit() {
    print_info "Setting up polkit rule for service restart..."
    
    cat > /etc/polkit-1/rules.d/49-nencloud.rules << EOF
// Allow $USER_NAME to restart/reload nencloud service without password
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.systemd1.restart-unit" ||
         action.id == "org.freedesktop.systemd1.reload-or-restart" ||
         action.id == "org.freedesktop.systemd1.manage-units") &&
        subject.user == "$USER_NAME" &&
        action.lookup("unit") == "nencloud.service") {
        return polkit.Result.YES;
    }
});
EOF

    chmod 644 /etc/polkit-1/rules.d/49-nencloud.rules

    print_success "Polkit rule configured for service restart"
}


# Test installation
test_installation() {
    print_info "Testing installation..."
    
    # Test client
    if sudo -u $USER_NAME $INSTALL_DIR/nencloud_client.py --config $CONFIG_DIR/client.json --test; then
        print_success "Client test successful"
    else
        print_warning "Client test failed - please check configuration"
    fi
}

# Start services
start_services() {
    print_info "Starting services..."
    
    systemctl start $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Nencloud daemon started successfully"
    else
        print_error "Failed to start daemon"
        systemctl status $SERVICE_NAME
        exit 1
    fi
}

# Show status
show_status() {
    echo
    print_success "=== Nencloud Client Installation Complete ==="
    echo
    echo "Installation Details:"
    echo "  • Install Directory: $INSTALL_DIR"
    echo "  • Config Directory: $CONFIG_DIR"
    echo "  • Log Directory: $LOG_DIR"
    echo "  • Service Name: $SERVICE_NAME"
    echo "  • System User: $USER_NAME (existing developer user)"
    echo
    echo "Service Management:"
    echo "  • Status:  systemctl status $SERVICE_NAME"
    echo "  • Start:   systemctl start $SERVICE_NAME"
    echo "  • Stop:    systemctl stop $SERVICE_NAME"
    echo "  • Restart: systemctl restart $SERVICE_NAME"
    echo "  • Logs:    journalctl -u $SERVICE_NAME -f"
    echo
    echo "Configuration:"
    echo "  • Config file: $CONFIG_DIR/client.json"
    echo "  • App config:  $(grep config_directory $CONFIG_DIR/client.json | cut -d'"' -f4)/appsettings.json"
    echo "  • Log file:    $LOG_DIR/daemon.log"
    echo
    echo "Manual Sync:"
    echo "  • Test: sudo -u $USER_NAME $INSTALL_DIR/nencloud_client.py --config $CONFIG_DIR/client.json --test"
    echo "  • Sync: sudo -u $USER_NAME $INSTALL_DIR/nencloud_client.py --config $CONFIG_DIR/client.json --sync"
    echo
    systemctl status $SERVICE_NAME --no-pager
}

# Uninstall function
uninstall() {
    print_info "Uninstalling Nencloud client..."
    
    # Stop and disable service
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_info "Stopping service..."
        systemctl stop $SERVICE_NAME
    fi
    
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        print_info "Disabling service..."
        systemctl disable $SERVICE_NAME
    fi
    
    # Remove systemd service
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        print_info "Removing systemd service..."
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
    fi
    
    # Remove log rotation
    if [[ -f "/etc/logrotate.d/nencloud" ]]; then
        print_info "Removing log rotation..."
        rm -f "/etc/logrotate.d/nencloud"
    fi
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Removing installation directory..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Remove config directory (but preserve appsettings.json)
    if [[ -d "$CONFIG_DIR" ]]; then
        print_info "Removing configuration directory..."
        rm -rf "$CONFIG_DIR"
    fi
    
    # Remove log directory
    if [[ -d "$LOG_DIR" ]]; then
        print_info "Removing log directory..."
        rm -rf "$LOG_DIR"
    fi
    
    print_success "Uninstallation completed successfully!"
    print_info "Note: appsettings.json files were preserved in their original locations."
}

# Update function
update() {
    print_info "Updating Nencloud client..."
    
    current_version=$(get_current_version)
    print_info "Current version: $current_version"
    print_info "New version: $SCRIPT_VERSION"
    
    if [[ "$current_version" == "$SCRIPT_VERSION" ]]; then
        print_warning "Already running version $SCRIPT_VERSION. No update needed."
        return
    fi
    
    # Stop service before update
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_info "Stopping service for update..."
        systemctl stop $SERVICE_NAME
    fi
    
    # Backup current config
    if [[ -f "$CONFIG_DIR/client.json" ]]; then
        print_info "Backing up current configuration..."
        cp "$CONFIG_DIR/client.json" "$CONFIG_DIR/client.json.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Update client files
    download_client_files
    create_daemon
    
    # Update/verify GPIO access (sudoers and reader script)
    setup_debugfs
    
    # Update systemd service
    create_service
    
    # Update log rotation
    setup_logging
    
    # Restart service
    systemctl daemon-reload
    systemctl start $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Update completed successfully!"
        print_info "Service restarted and is running."
        
        # Verify GPIO access
        echo
        print_info "Verifying GPIO access..."
        if sudo -u $USER_NAME sudo $INSTALL_DIR/read_gpio.sh > /dev/null 2>&1; then
            print_success "GPIO access working"
        else
            print_warning "GPIO access may not be working - check logs"
        fi
        
        # Check for sudo errors in recent logs
        sleep 2
        if journalctl -u $SERVICE_NAME --since "10 seconds ago" | grep -q "pam_unix.*auth"; then
            print_warning "Detected authentication errors in logs - GPIO may not be working"
            print_info "Check with: journalctl -u $SERVICE_NAME -f"
        fi
    else
        print_warning "Update completed but service failed to start."
        print_info "Check logs with: journalctl -u $SERVICE_NAME"
    fi
}

# Show usage
show_usage() {
    echo "=============================================="
    echo "  Nencloud Client Installation Script"
    echo "          Version $SCRIPT_VERSION"
    echo "=============================================="
    echo
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  (no option)     Install Nencloud client"
    echo "  --update        Update existing installation"
    echo "  --uninstall     Remove Nencloud client"
    echo "  --status        Show installation status"
    echo "  --version       Show script version"
    echo "  --help          Show this help message"
    echo
    echo "Examples:"
    echo "  sudo $0                    # Install"
    echo "  sudo $0 --update          # Update existing installation"
    echo "  sudo $0 --uninstall       # Remove installation"
    echo "  sudo $0 --status          # Check status"
    echo
}

# Show status
show_status() {
    echo "=============================================="
    echo "  Nencloud Client Status"
    echo "=============================================="
    echo
    
    if check_installation; then
        current_version=$(get_current_version)
        echo "✓ Installation found"
        echo "  • Version: $current_version"
        echo "  • Install Directory: $INSTALL_DIR"
        echo "  • Config Directory: $CONFIG_DIR"
        echo "  • Log Directory: $LOG_DIR"
        echo "  • Service Name: $SERVICE_NAME"
        echo
        
        # Check service status
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo "✓ Service is running"
        else
            echo "✗ Service is not running"
        fi
        
        if systemctl is-enabled --quiet $SERVICE_NAME; then
            echo "✓ Service is enabled (starts on boot)"
        else
            echo "✗ Service is not enabled"
        fi
        
        # Check config
        if [[ -f "$CONFIG_DIR/client.json" ]]; then
            echo "✓ Configuration file exists"
        else
            echo "✗ Configuration file missing"
        fi
        
        echo
        echo "Service Management:"
        echo "  • Status:  systemctl status $SERVICE_NAME"
        echo "  • Logs:    journalctl -u $SERVICE_NAME -f"
        echo "  • Restart: systemctl restart $SERVICE_NAME"
        echo
        
    else
        echo "✗ No installation found"
        echo
        echo "To install, run: sudo $0"
    fi
}

# Main installation flow
main() {
    echo "=============================================="
    echo "  Nencloud Client Installation Script"
    echo "          Version $SCRIPT_VERSION"
    echo "=============================================="
    echo
    
    check_root
    detect_os
    install_dependencies
    verify_user
    create_directories
    download_client_files
    configure_client
    create_daemon
    setup_debugfs
    create_service
    setup_logging
    setup_polkit
    test_installation
    start_services
    show_status
    
    echo
    print_success "Installation completed successfully!"
    print_info "The Nencloud daemon is now running and will automatically sync your configuration."
    echo
    print_info "Note: This version uses apt-installed python3-requests instead of pip to avoid externally-managed-environment issues."
}

# Parse command line arguments
case "${1:-}" in
    --update)
        check_root
        if check_installation; then
            update
        else
            print_error "No installation found to update. Please install first."
            exit 1
        fi
        ;;
    --uninstall)
        check_root
        if check_installation; then
            uninstall
        else
            print_error "No installation found to uninstall."
            exit 1
        fi
        ;;
    --status)
        show_status
        ;;
    --version)
        echo "Nencloud Client Installation Script Version $SCRIPT_VERSION"
        ;;
    --help|-h)
        show_usage
        ;;
    "")
        # No arguments - run main installation
        main "$@"
        ;;
    *)
        print_error "Unknown option: $1"
        echo
        show_usage
        exit 1
        ;;
esac 