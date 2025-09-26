#!/usr/bin/env python3
#
# NAS Data Backup Script
# ----------------------
# This script backs up data from ZFS snapshots on a remote NAS server using rsync.
#
# Features:
# - Processes multiple backup configurations from a single multi-document YAML file
# - Automatically discovers and uses the latest ZFS snapshot from the remote server
# - Creates organized backup directories based on snapshot names
# - Supports custom rsync arguments per configuration
# - Generates detailed logs for each backup job in temporary directories
# - Validates remote directories exist before attempting backup
# - Reports timing and success/failure for each configuration
#
# Usage:
#   ./backup-nas-data.py [-d DESTINATION_ROOT] [-v]
#
# Arguments:
#   -d, --destination-root  Root directory for backups (default: ~/nas_backup)
#   -v, --verbose          Enable verbose output
#
# Configuration:
#   Place config.yaml in the destination root directory with multiple documents
#   Each document should define:
#     name                     - Configuration name (optional)
#     dataset                  - ZFS dataset name on remote server
#     subdir                   - Subdirectory within dataset (optional)
#     override_destination_name - Custom destination directory name (optional)
#     rsync_extra_args         - Additional rsync arguments (optional)
#
# Exit codes:
#   0   - Success (all backups completed successfully)
#   1   - Bad command line arguments
#   2   - Configuration file error
#   3   - Could not determine snapshot name
#   4   - One or more backup jobs failed
#   100 - Other error
#
# Requirements:
#   - SSH access to remote NAS server (media002)
#   - ZFS utilities available on remote server
#   - rsync installed locally and remotely
#   - PyYAML package (pip install pyyaml)

import argparse
import os
import sys
import subprocess
import time
import yaml
from pathlib import Path
from datetime import datetime
from tempfile import gettempdir
from typing import Dict, Iterator

# Exit codes
EXIT_SUCCESS = 0
ENO_BAD_CLI = 1
ENO_BAD_CONFIG_FILE = 2
ENO_UNKNOWN_SNAPSHOT = 3
ENO_FAILED_JOB = 4
ENO_OTHER = 100

# Configuration
DEFAULT_BACKUP_ROOT_DIR = Path.home() / "nas_backup"
SSH_HOST = "media002"

class BackupExecutor:
    def __init__(self, destination_root: str, verbose: bool = False):
        self.verbose = verbose
        self.destination_root = Path(destination_root)
        self.snapshot_name = ""
        self.snapshot_backup_dir = ""
        self.log_dir = ""

        self.config_file = self.destination_root / "config.yaml"

    def main(self) -> int:
        """Main execution function"""

        # Process all configurations from the single YAML file
        configs = list(self.load_all_configs())
        if not configs:
            print(f"No configurations found in {self.config_file}")
            return ENO_BAD_CONFIG_FILE

        if not self.set_snapshot_name():
            print("Error: Could not determine snapshot name")
            return ENO_UNKNOWN_SNAPSHOT

        if not self.set_log_dir():
            print("Error: Could not set log directory")
            return ENO_OTHER
        
        has_error = False
        
        for config, config_name in configs:
            start_time = time.time()
            
            if not self.process_config(config, config_name):
                has_error = True
            
            duration = int(time.time() - start_time)
            hours = duration // 3600
            minutes = (duration % 3600) // 60
            seconds = duration % 60
            print(f"Elapsed time: {hours:02d}h {minutes:02d}m {seconds:02d}s")
        
        if has_error:
            print("One or more configurations had errors.")
            print(f"Log files are available in: {self.log_dir}")
            return ENO_FAILED_JOB
        else:
            print("All configurations processed successfully.")
            print(f"Log files are available in: {self.log_dir}")
            return 0

    def load_all_configs(self) -> Iterator[tuple[Dict, str]]:
        """Load all configuration documents from the single YAML file"""
        try:
            
            with open(self.config_file, 'r') as f:
                # Load all documents from the YAML file
                documents = yaml.safe_load_all(f)
                
                for i, config in enumerate(documents):
                    # Generate a name for each configuration
                    if config is None:
                        continue
                    
                    # Try to get a name from the config, otherwise use index
                    config_name = config.get('name', f'config_{i+1}')
                    yield config, config_name
                    
        except FileNotFoundError:
            print(f"Error: Configuration file {self.config_file} not found")
            return
        except yaml.YAMLError as e:
            print(f"Error: Invalid YAML in {self.config_file}: {e}")
            return
        except Exception as e:
            print(f"Error loading configurations: {e}")
            return

    def process_config(self, config: Dict, config_name: str) -> bool:
        """Process a single configuration document"""
        print(f"Processing configuration: {config_name}")
        
        try:
            # Handle empty config documents
            if config is None:
                print(f"Warning: Empty configuration document for {config_name}")
                return False
            
            # Extract configuration values
            dataset = config.get('dataset', '')
            subdir = config.get('subdir', '')
            override_destination_name = config.get('override_destination_name', '')
            rsync_extra_args = config.get('rsync_extra_args', [])
            
            if not dataset:
                print(f"Error: dataset not set in configuration {config_name}")
                return False
            
            self.print_verbose(f"Dataset: {dataset}")
            
            # Get dataset mount point via SSH
            try:
                result = subprocess.run([
                    'ssh', SSH_HOST, 'zfs', 'get', '-Ho', 'value', 'mountpoint', dataset
                ], capture_output=True, text=True, check=True)
                dataset_mount_point = result.stdout.strip()
            except subprocess.CalledProcessError:
                print(f"Error: Could not determine mount point for dataset {dataset}")
                return False
            
            self.print_verbose(f"Mount point: {dataset_mount_point}")
            
            if not dataset_mount_point:
                print(f"Error: Could not determine mount point for dataset {dataset}")
                return False
            
            # Add your backup logic here
            # This is where the actual backup operations would be implemented
            remote_dir = f"{dataset_mount_point}/.zfs/snapshot/{self.snapshot_name}".rstrip('/')
            if subdir:
                remote_dir = f"{remote_dir}/{subdir.lstrip('/')}".rstrip('/')
            self.print_verbose(f"Remote directory: {remote_dir}")

            # Verify remote directory exists
            try:
                _ = subprocess.run([
                    'ssh', SSH_HOST, f"[ -d '{remote_dir}' ]"
                ], check=True)
            except subprocess.CalledProcessError:
                print(f"Error: Remote directory {remote_dir} does not exist for dataset {dataset}")
                return False
            
            destination_dir_name = override_destination_name if override_destination_name else config_name
            destination_dir = self.snapshot_backup_dir / destination_dir_name
            self.print_verbose(f"Destination directory: {destination_dir}")

            try:
                os.makedirs(destination_dir, exist_ok=False)
            except FileExistsError:
                print(f"Error: Destination directory {destination_dir} already exists")
                return False
            except Exception as e:
                print(f"Error creating destination directory {destination_dir}: {e}")
                return False

            rsync_cmd = ['rsync', '--archive', '--verbose']
            if rsync_extra_args:
                rsync_cmd.extend(rsync_extra_args)
            rsync_cmd.extend([f"{SSH_HOST}:{remote_dir}/", f"{destination_dir}/"])
            
            rsync_proc = subprocess.run(rsync_cmd, capture_output=True, text=True)

            log_file_path = self.log_dir / f"{config_name.replace(' ', '_')}.log"
            with open(log_file_path, 'w') as log_file:
                log_file.write(f"Rsync command: {' '.join(rsync_cmd)}\n\n")
                log_file.write("Rsync output:\n")
                log_file.write(rsync_proc.stdout)
                log_file.write("\nRsync errors:\n")
                log_file.write(rsync_proc.stderr)

            if rsync_proc.returncode != 0:
                print(f"Error: Rsync failed for configuration {config_name}. See log: {log_file_path}")
                return False
            else:
                print(f"Backup completed successfully for configuration {config_name}. See log: {log_file_path}")
                return True
            
        except Exception as e:
            print(f"Error processing configuration {config_name}: {e}")
            return False

    def print_verbose(self, *args):
        """Print verbose messages if verbose mode is enabled"""
        if self.verbose:
            print(*args)

    def set_log_dir(self) -> bool:
        """Set the log directory for this execution"""
        self.log_dir = Path(gettempdir()) / f"backup-nas-data-logs-{datetime.now().strftime('%y%m%d-%H%M%S')}"

        try:
            os.makedirs(self.log_dir, exist_ok=True)
        except Exception as e:
            print(f"Error creating logs directory {self.log_dir}: {e}")
            return False
        return True


    def set_snapshot_name(self) -> bool:
        """Set the snapshot name from remote zfs snapshots"""
        try:
            snapshots_raw = subprocess.run([
                'ssh', SSH_HOST, 'zfs', 'list', '-t', 'snapshot', '-H', '-o', 'name'
            ], capture_output=True, text=True, check=True)
            snapshots = snapshots_raw.stdout.strip()
        except subprocess.CalledProcessError:
            print(f"Error: Could not fetch snapshots from remote host {SSH_HOST}")
            return False

        if not snapshots:
            print(f"Error: No snapshots found on remote host {SSH_HOST}")
            return False

        # Extract snapshot names
        snapshots = [line.split('@')[1] for line in snapshots.split('\n') if line]
        snapshots = sorted(set(snapshots))
        self.snapshot_name = snapshots[-1]  # Use the latest snapshot

        self.snapshot_backup_dir = self.destination_root / self.snapshot_name

        # create snapshot backup dir if it doesn't exist
        try:
            os.makedirs(self.snapshot_backup_dir, exist_ok=True)
        except Exception as e:
            print(f"Error creating snapshot backup directory {self.snapshot_backup_dir}: {e}")
            return False

        return True

def main():
    """Entry point with argument parsing"""
    parser = argparse.ArgumentParser(
        description="Backup NAS data using a single multi-document YAML configuration file",
        add_help=True
    )
    parser.add_argument(
        '-d', '--destination-root', 
        action='store',
        type=str,
        default=str(DEFAULT_BACKUP_ROOT_DIR),
        help='The root directory where backups will be stored (default: ~/nas_backup)'
    )
    parser.add_argument(
        '-v', '--verbose', 
        action='store_true',
        help='Enable verbose output'
    )
    
    # TODO: how to exit with proper code on error if parsing fails?
    # https://stackoverflow.com/questions/5943249/python-argparse-and-controlling-overriding-the-exit-status-code
    args = parser.parse_args()
    
    backup_executor = BackupExecutor(
        destination_root=args.destination_root,
        verbose=args.verbose)
    return backup_executor.main()

if __name__ == "__main__":
    sys.exit(main())