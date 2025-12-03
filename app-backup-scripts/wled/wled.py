import requests
import subprocess
from typing import Dict, Any, Tuple

class Handler:
    _config_file_name = "cfg.json"
    _presets_file_name = "presets.json"

    def _backup_file(self, controller_ip: str, file_name: str, temp_dir: str) -> None:
        """
        Backup configuration file from WLED controller.
        """
        print(f"Backing up {file_name} from WLED controller at {controller_ip}...")

        url = f"http://{controller_ip}/{file_name}"

        response = requests.get(url, timeout=30)

        if response.status_code != 200:
            raise Exception(f"Failed to get {file_name}: HTTP {response.status_code} - {response.text}")

        with open(f"{temp_dir}/{file_name}", 'wb') as f:
            f.write(response.content)

        print(f"Successfully backed up {file_name} to {temp_dir}/{file_name}.")

    def _make_tar_file(self, backup_dir: str, tar_dir: str, tar_file: str) -> None:
        print("Creating final tar file...")

        tar_file_full_name = f"{backup_dir}/{tar_file}"

        proc = subprocess.run(
            ["tar", "-czf", tar_file_full_name, "-C", tar_dir, "./"],
            capture_output=True,
            text=True
        )

        if proc.returncode != 0:
            raise Exception(f"Tar command failed: {proc.stderr.strip()}")

        print (f"Successfully created backup: {tar_file_full_name}.")

    def run(self, vars_dict: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Process WLED backup with given variables.
        
        Returns a tuple indicating success and a message.
        """
        try:
            backup_dir = vars_dict.get('backup_dir', None)
            temp_dir = vars_dict.get('temp_dir', None)
            tar_file = vars_dict.get('tar_file', None)
            controller_ip = vars_dict.get('controller_ip', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."
            if not temp_dir:
                return False, "temp_dir not defined."

            # From config.yml
            if not controller_ip:
                return False, "'controller_ip' not defined."

            self._backup_file(controller_ip, self._config_file_name, temp_dir)
            self._backup_file(controller_ip, self._presets_file_name, temp_dir)

            self._make_tar_file(backup_dir, temp_dir, tar_file)

            return True, f"Backup created successfully."

        except Exception as e:
            return False, f"Exception occurred during backup process: {str(e)}"
