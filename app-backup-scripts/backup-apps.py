#!/usr/bin/env python3
from datetime import datetime
import importlib.util
import grp
import os
from pathlib import Path
import subprocess
import sys
import stat
from shutil import rmtree
import traceback
import yaml
from tempfile import mkdtemp
from typing import Any, Dict, List, Tuple

BACKUP_DIR_ROOT = Path(os.environ.get('BACKUP_DIR', '/var/local/backups'))
CONFIG_PATH = Path(os.environ.get('CONFIG_PATH', '/usr/local/etc/backup-apps/config.yml'))
KEEP_PREVIOUS_BACKUPS = int(os.environ.get('KEEP_PREVIOUS_BACKUPS', '0'))
SCRIPT_DIR = Path(os.environ.get('SCRIPT_DIR', '/usr/local/lib/backup-apps'))

class CoreProcessor:
    def get_processor_class(self, module, name: str):
        """Get the processor class from the loaded module."""
        # Try different class naming conventions
        possible_root_names = [
            name.replace('-', '').replace('_', '').title(),
            name.replace('-', '_').title(),
            name.title(),
            name,
        ]
        possible_class_suffixes = ['Processor', 'Handler', 'Runner']

        possible_class_names = [r + s for r in set(possible_root_names) for s in possible_class_suffixes]
        possible_class_names.extend(possible_class_suffixes)

        for class_name in possible_class_names:
            if hasattr(module, class_name):
                return getattr(module, class_name)
        
        raise AttributeError(f"No processor class found in module {name}. "
                           f"Tried: {', '.join(possible_class_names)}")

    def load_config(self, config_path: str) -> List[Dict[str, Any]]:
        """Load the YAML configuration file."""
        documents = []
        with open(config_path, 'r') as f:
            for doc in yaml.safe_load_all(f):
                if doc:     # Skip empty documents
                    documents.append(doc)
        return documents

    def load_module(self, name: str):
        """Dynamically load a Python module by name from the scripts directory."""
        script_path = SCRIPT_DIR / f"{name}.py"

        if not script_path.exists():
            raise FileNotFoundError(f"Script file not found: {script_path}")

        try:
            spec = importlib.util.spec_from_file_location(name, script_path)
            if spec is None or spec.loader is None:
                raise ImportError(f"Could not create module spec for {script_path}")
            
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module
        except Exception as e:
            raise ImportError(f"Failed to load module {name}: {e}")

    def make_document_tar_file(
            self,
            tar_dir: str,
            tar_name: str,
            destination_dir: str,
            tar_exclude: List[str]) -> bool:
        """Create a tar file for the document."""

        # we're going to skip parameter validation because this function
        # is intended to be called internally with validated parameters.

        try:
            tar_file_full_name = f"{destination_dir}/{tar_name}.tar.zst"

            # Build tar command with exclusions
            cmd = ["tar", "-c", "--use-compress-program", "zstd -19 -T2", "-f", tar_file_full_name]
            for exclude in tar_exclude:
                cmd.extend(["--exclude", exclude])
            cmd.extend(["-C", tar_dir, "./"])

            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            if proc.returncode != 0:
                self.print_module_message(f"Tar command failed: {proc.stderr.strip()}")
                return False

        except Exception as e:
            self.print_module_message(f"Error creating tar file {tar_name}: {e}")
            return False

        return True

    def print_module_message(self, message: str, level: int = 1):
        """Print a message with the module name as prefix."""
        indent = "  " * level
        print(f"{indent}{message}")

    def print_ok_or_fail(self, print_ok: bool, message: str):
        if print_ok:
            print(f"OK: {message}")
        else:
            print(f"FAIL: {message}")

    def process_config(self, config_path: str) -> bool:
        """Process the configuration file and execute backup scripts."""

        print(f"Loading config file: {config_path}")
        try:
            documents = self.load_config(config_path)
        except Exception as e:
            print(f"Failed to load config: {e}")
            return False

        os.umask(0o027)  # drwxr-x---, rw-r-----

        if not os.path.isdir(BACKUP_DIR_ROOT):
            print(f"Backup root directory {BACKUP_DIR_ROOT} does not exist. Please create it with the following permissions: drwxr-s--- root:adm")
            return False

        backup_date = datetime.now().strftime("%y%m%d")

        result = True
        for doc in documents:
            name = doc.get('name', None)

            if not name or len(name) < 1:
                result = False
                self.print_ok_or_fail(False, "Document missing 'name' field. Skipping.")
                continue
            if doc.get('disabled', False):
                self.print_ok_or_fail(True, f"Skipping document {name} (disabled).")
                continue

            print(f"Processing document {name}...")

            backup_dir = BACKUP_DIR_ROOT / name
            success = self.process_document(doc,
                                            backup_date=backup_date,
                                            backup_dir=backup_dir)

            if not success:
                result = False
                self.print_ok_or_fail(False, f"Failed to process document {name}.")
            else:
                self.print_ok_or_fail(True, f"Successfully processed document {name}.")

        return result

    def process_document(self, doc: Dict[str, Any], **kwargs) -> Tuple[bool, str]:
        """Process a single document from the config."""

        name = doc.get('name')
        modules = doc.get('modules', [])
        make_temp_dir = doc.get('requires_temp_dir', False)
        skip_final_tar = doc.get('skip_final_tar', False)
        vars_dict = doc.get('vars', {})
        tar_dir = vars_dict.get('tar_dir')

        backup_dir = kwargs.get('backup_dir')
        tar_file = f"{name}.{kwargs.get('backup_date')}"
        temp_dir = ""

        # update vars_dict with additional variables
        vars_dict.update(kwargs)
        vars_dict['tar_file'] = tar_file
        vars_dict['backup_dir'] = backup_dir

        try:
            if make_temp_dir:
                temp_dir = mkdtemp()
                vars_dict['temp_dir'] = temp_dir

            # Create the backup dir or remove previous backups
            if not os.path.isdir(backup_dir):
                os.makedirs(backup_dir)
            else:
                previous_backups = sorted([f for f in os.listdir(backup_dir) if os.path.isfile(backup_dir / f)])
                if KEEP_PREVIOUS_BACKUPS > 0 and len(previous_backups) > KEEP_PREVIOUS_BACKUPS:
                    previous_backups = previous_backups[:-KEEP_PREVIOUS_BACKUPS]
                for filename in previous_backups:
                    filepath = backup_dir / filename
                    os.remove(filepath)

            modules_result = self.process_document_modules(modules, vars_dict)

            if not skip_final_tar and modules_result:
                modules_result = self.make_document_tar_file(
                    temp_dir if temp_dir else tar_dir,
                    tar_file,
                    backup_dir,
                    vars_dict.get('tar_exclude', []))
            
            if make_temp_dir:
                try:
                    rmtree(temp_dir, ignore_errors=True)
                except OSError as e:
                    pass

            return modules_result

        except Exception as e:
            print(f"Error processing document {name}: {str(e)}\n{traceback.format_exc()}")
            return False

    def process_document_modules(self, modules: List[str], vars_dict: Dict[str, Any])-> bool:
        for module_name in modules:
            try:
                self.print_module_message(f"Processing module {module_name}...")

                # Load the module dynamically
                module = self.load_module(module_name)

                # Get the processor class
                processor_class = self.get_processor_class(module, module_name)
                processor = processor_class()

                # Check if the class has a 'run' method
                if not hasattr(processor, 'run'):
                    self.print_module_message(f"Processor class in {module_name}.py missing 'run' method.")
                    return False

                # call the run method with vars_dict
                proc_result = processor.run(vars_dict, lambda x: self.print_module_message(x, 2))

                # Handle different return types
                if isinstance(proc_result, bool):
                    if proc_result:
                        self.print_module_message(f"Successfully processed module {module_name}")
                    else:
                        self.print_module_message(f"Processing failed for module {module_name}")
                        return False
                elif isinstance(proc_result, tuple):
                    if len(proc_result) != 2:
                        self.print_module_message(f"Invalid return type for module {module_name}. Expected a tuple of length 2.")
                        return False
                    if proc_result[0]:
                        self.print_module_message(f"Successfully processed module {module_name}")
                    else:
                        self.print_module_message(proc_result[1])
                        self.print_module_message(f"Processing failed for module {module_name}")
                        return False
                elif isinstance(proc_result, str):
                    # assume that a string return is an error message
                    self.print_module_message(proc_result)
                    return False
                else:
                    self.print_module_message(f"Successfully processed module {module_name}")

            except Exception as e:
                self.print_module_message(f"Error occurred while processing module {module_name}: {str(e)}")
                return False

        return True

def main():
    processor = CoreProcessor()

    config_path = CONFIG_PATH
    success = processor.process_config(config_path)

    if success:
        print("Done.")
    else:
        print("A problem occurred during processing.")
        sys.exit(1)

if __name__ == "__main__":
    main()