from collections.abc import Callable
import subprocess
from typing import Dict, Any, Tuple

class Handler:
    def _dump_database(self, temp_dir: str, container_name: str) -> None:
        self._print_func("Dumping database...")

        docker_process = subprocess.Popen([
            'docker', 'exec', '-t', container_name, 'pg_dump', '-c',
            '-U', 'postgres', '-d', 'videodl'
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

        with open(f"{temp_dir}/videodl-db.sql", 'wb') as f:
            f.write(output)

        self._print_func("Database dump completed successfully.")

    def run(self, vars_dict: Dict[str, Any], print_func: Callable[[str], None]) -> Tuple[bool, str]:
        """
        Process VideoDL backup with given variables.
        
        Returns a tuple indicating success and a message.
        """
        self._print_func = print_func

        try:
            temp_dir = vars_dict.get('temp_dir', None)
            container_name = vars_dict.get('container_name', None)

            # From caller
            if not temp_dir:
                return False, "temp_dir not defined."

            # From config
            if not container_name:
                return False, "'container_name' not defined in config."

            self._dump_database(temp_dir, container_name)

            return True, f"Successfully created backup."
        except Exception as e:
            return False, f"Exception occurred: {str(e)}"