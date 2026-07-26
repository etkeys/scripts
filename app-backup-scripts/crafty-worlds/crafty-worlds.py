
from collections.abc import Callable
import os
import subprocess
import shutil
from typing import Dict, Any, Tuple

class Handler:
    def process_world(self, world_dir: str, world_backup_dir: str):
        """
        Process a specific world for backup.
        """
        # A world directory can contain multiple backup job directories.
        for job_id in os.listdir(world_dir):
            job_dir = os.path.join(world_dir, job_id)
            job_backup_dir = os.path.join(world_backup_dir, job_id)

            if os.path.exists(job_backup_dir):
                shutil.rmtree(job_backup_dir)
            os.makedirs(job_backup_dir, exist_ok=True)

            job_files = sorted(os.listdir(job_dir))
            if job_files:
                newest_file = job_files[-1]
                src_path = os.path.join(job_dir, newest_file)
                dest_path = os.path.join(job_backup_dir, newest_file)
                self._print_func(f"Copying {src_path} to {dest_path}.")
                shutil.copy2(src_path, dest_path)

    def run(self, vars_dict: Dict[str, Any], print_func: Callable[[str], None]) -> Tuple[bool, str]:
        """
        Process Crafty minecraft world servers backups with given variables.
        
        Returns a tuple indicating success and a message.
        """

        self._print_func = print_func

        try:
            backup_dir = vars_dict.get('backup_dir', None)
            worlds_backup_root_dir = vars_dict.get('worlds_backup_root_dir', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."

            # From config
            if not worlds_backup_root_dir:
                return False, "worlds_backup_root_dir variable is missing."

            # Enumerate over each world subdirectory in the crafty backups directory
            for world_id in os.listdir(worlds_backup_root_dir):
                self._print_func(f"Processing world: {world_id}")

                world_dir = os.path.join(worlds_backup_root_dir, world_id)
                world_backup_dir = os.path.join(backup_dir, world_id)

                os.makedirs(world_backup_dir, exist_ok=True)

                self.process_world(world_dir, world_backup_dir)

                self._print_func(f"Finished processing world: {world_id}")

        except Exception as e:
            return False, f"Exception occurred: {str(e)}"