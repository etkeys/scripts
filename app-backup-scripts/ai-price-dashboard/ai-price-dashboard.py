
from collections.abc import Callable
import subprocess
from typing import Dict, Any, Tuple

class Handler:
    def _dump_dashboard_files(self, temp_dir: str, container_name: str) -> None:
        self._print_func("Dumping AI Price Dashboard files...")

        proc = subprocess.run([
            'docker', 'cp',
            f"{container_name}:/data/app.db",
            f"{temp_dir}/app.db"
        ], capture_output=True, text=True)

        if proc.returncode != 0:
            raise Exception(f"Failed to copy app.db: {proc.stderr.strip()}")

        self._print_func("AI Price Dashboard files dumped successfully.")

    def run(self, vars_dict: Dict[str, Any], print_func: Callable[[str], None]) -> Tuple[bool, str]:
        """
        Process AI Price Dashboard backup with given variables.
        
        Returns a tuple indicating success and a message.
        """

        self._print_func = print_func

        try:
            backup_dir = vars_dict.get('backup_dir', None)
            temp_dir = vars_dict.get('temp_dir', None)
            tar_file = vars_dict.get('tar_file', None)
            container_names = vars_dict.get('container_names', {})
            ai_price_dashboard_container_name = container_names.get('ai_price_dashboard', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."
            if not temp_dir:
                return False, "temp_dir not defined."

            # From config
            if not ai_price_dashboard_container_name:
                return False, "'ai_price_dashboard' not defined in config."

            self._dump_dashboard_files(temp_dir, ai_price_dashboard_container_name)

            return True, f"Successfully created backup."
        except Exception as e:
            return False, f"Exception occurred: {str(e)}"