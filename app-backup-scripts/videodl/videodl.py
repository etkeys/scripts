import subprocess
from typing import Dict, Any, Tuple

class Handler:
    def _dump_database(self, temp_dir: str, container_name: str) -> None:
        print("Dumping LiteLLM database...")

        docker_process = subprocess.Popen([
            'docker', 'exec', '-t', container_name, 'pg_dump', '-c',
            '-U', 'postgres', '-d', 'videodl'
        ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        gzip_process = subprocess.Popen([
            'gzip'
        ],
            stdin=docker_process.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        # Allow docker_process to receive a SIGPIPE if gzip_process exits.
        docker_process.stdout.close() 

        # Get the compressed output
        compressed_output, gzip_err = gzip_process.communicate()

        # Wait for docker process to finish
        docker_err = docker_process.stderr.read()
        docker_return_code = docker_process.wait()

        if docker_return_code != 0:
            raise Exception(f"Database dump failed {docker_return_code}: {docker_err.decode('utf-8')}")
        if gzip_process.returncode != 0:
            raise Exception(f"Gzip process failed {gzip_process.returncode}: {gzip_err.decode('utf-8')}")
        if not compressed_output:
            raise Exception("No output from gzip process.")

        with open(f"{temp_dir}/videodl-db.sql.gz", 'wb') as f:
            f.write(compressed_output)

        print("Database dump completed successfully.")

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
        Process Open-WebUI backup with given variables.
        
        Returns a tuple indicating success and a message.
        """
        try:
            backup_dir = vars_dict.get('backup_dir', None)
            temp_dir = vars_dict.get('temp_dir', None)
            tar_file = vars_dict.get('tar_file', None)
            container_name = vars_dict.get('container_name', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."
            if not temp_dir:
                return False, "temp_dir not defined."

            # From config
            if not container_name:
                return False, "'container_name' not defined in config."

            self._dump_database(temp_dir, container_name)
            self._make_tar_file(backup_dir, temp_dir, tar_file)

            return True, f"Successfully created backup."
        except Exception as e:
            return False, f"Exception occurred: {str(e)}"