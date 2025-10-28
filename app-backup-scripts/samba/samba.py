import subprocess
from typing import Dict, Any, Tuple

class Handler:
    def run(self, vars_dict: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Process Samba backup with given variables.
        
        Returns a tuple indicating success and a message.
        """
        try:
            backup_dir = vars_dict.get('backup_dir', None)
            tar_dir = vars_dict.get('tar_dir', None)
            tar_file = vars_dict.get('tar_file', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."

            # From config.yml
            if not tar_dir:
                return False, "tar_dir not defined."

            tar_file_full_name = f"{backup_dir}/{tar_file}"

            proc = subprocess.run(
                ["tar", "-czf", tar_file_full_name, "-C", tar_dir, "./"],
                capture_output=True,
                text=True
            )

            if proc.returncode != 0:
                return False, f"Tar command failed: {proc.stderr.strip()}"

            return True, f"Successfully created backup: {tar_file_full_name}."
        except Exception as e:
            return False, f"Exception occurred: {str(e)}"
