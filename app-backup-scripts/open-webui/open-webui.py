from collections.abc import Callable
import subprocess
from typing import Dict, Any, Tuple

class Handler:
    def _dump_litellm_database(self, temp_dir: str, container_name: str) -> None:
        self._print_func("Dumping LiteLLM database...")

        docker_process = subprocess.Popen([
            'docker', 'exec', '-t', container_name, 'pg_dump', '-c',
            '-U', 'llmproxy', '-d', 'litellm'
        ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        # Get the output
        output, docker_err = docker_process.communicate()

        docker_return_code = docker_process.wait()

        if docker_return_code != 0:
            raise Exception(f"Database dump failed {docker_return_code}: {docker_err.decode('utf-8')}")
        if not output:
            raise Exception("No output from pg_dump process.")

        with open(f"{temp_dir}/litellm-db.sql", 'wb') as f:
            f.write(output)

        self._print_func("Database dump completed successfully.")

    def _dump_openwebui_files(self, temp_dir: str, container_name: str) -> None:
        self._print_func("Dumping Open-WebUI files...")

        proc = subprocess.run([
            'docker', 'cp',
            f"{container_name}:/app/backend/data/webui.db",
            f"{temp_dir}/webui.db"
        ], capture_output=True, text=True)

        if proc.returncode != 0:
            raise Exception(f"Failed to copy webui.db: {proc.stderr.strip()}")

        self._print_func("Open-WebUI files dumped successfully.")

    def run(self, vars_dict: Dict[str, Any], print_func: Callable[[str], None]) -> Tuple[bool, str]:
        """
        Process Open-WebUI backup with given variables.
        
        Returns a tuple indicating success and a message.
        """

        self._print_func = print_func

        try:
            backup_dir = vars_dict.get('backup_dir', None)
            temp_dir = vars_dict.get('temp_dir', None)
            tar_file = vars_dict.get('tar_file', None)
            container_names = vars_dict.get('container_names', {})
            db_container_name = container_names.get('litellm_db', None)
            openwebui_container_name = container_names.get('open_webui', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."
            if not temp_dir:
                return False, "temp_dir not defined."

            # From config
            if not db_container_name:
                return False, "'db_container_name' not defined in config."
            if not openwebui_container_name:
                return False, "'open_webui' not defined in config."

            self._dump_litellm_database(temp_dir, db_container_name)
            self._dump_openwebui_files(temp_dir, openwebui_container_name)

            return True, f"Successfully created backup."
        except Exception as e:
            return False, f"Exception occurred: {str(e)}"