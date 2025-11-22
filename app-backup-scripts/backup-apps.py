#!/usr/bin/env python3
from datetime import datetime
import importlib.util
import grp
import os
from pathlib import Path
import sys
import stat
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

    def process_config(self, config_path: str) -> List[Tuple[str, bool ,str]]:
        """Process the configuration file and execute backup scripts."""

        try:
            documents = self.load_config(config_path)
        except Exception as e:
            return [("config_load", False, f"Failed to load config: {str(e)}")]

        os.umask(0o027)  # drwxr-x---, rw-r-----

        if not os.path.isdir(BACKUP_DIR_ROOT):
            return [("backup_dir", False, f"Backup root directory {BACKUP_DIR_ROOT} does not exist. Please create it with the following permissions: drwxr-s--- root:adm")]

        backup_date = datetime.now().strftime("%y%m%d")

        results = []
        for doc in documents:
            name = doc.get('name', None)

            if not name:
                results.append(("config", False, "Document missing 'name' field."))
                continue
            if doc.get('disabled', False):
                results.append(("config", True, f"Skipping '{name}' (disabled)."))
                continue

            backup_dir = BACKUP_DIR_ROOT / name
            success, message = self.process_document(doc,
                                                     backup_date=backup_date,
                                                     backup_dir=backup_dir)
            results.append((name, success, message))

        return results

    def process_document(self, doc: Dict[str, Any], **kwargs) -> Tuple[bool, str]:
        """Process a single document from the config."""

        name = doc.get('name')
        make_temp_dir = doc.get('requires_temp_dir', False)
        vars_dict = doc.get('vars', {})
        backup_dir = kwargs.get('backup_dir')

        if not name or len(name) < 1:
            return False, "Missing 'name' in document."

        try:
            # Load the module dynamically
            module = self.load_module(name)

            # Get the processor class
            processor_class = self.get_processor_class(module, name)
            processor = processor_class()

            # Check if the class has a 'run' method
            if not hasattr(processor, 'run'):
                return False, f"Processor class in {name}.py missing 'run' method."

            if not os.path.isdir(backup_dir):
                os.makedirs(backup_dir)
            else:
                previous_backups = sorted([f for f in os.listdir(backup_dir) if os.path.isfile(backup_dir / f)])
                if KEEP_PREVIOUS_BACKUPS > 0 and len(previous_backups) > KEEP_PREVIOUS_BACKUPS:
                    num_to_delete = len(previous_backups) - KEEP_PREVIOUS_BACKUPS
                    previous_backups = previous_backups[:num_to_delete]
                    for filename in previous_backups:
                        file_path = backup_dir / filename
                        if os.path.isfile(file_path):
                            os.remove(file_path)

            # update vars_dict with additional variables
            vars_dict.update(kwargs)
            vars_dict['tar_file'] = f"{name}.{kwargs.get('backup_date')}.tar.gz"

            if make_temp_dir:
                temp_dir = mkdtemp()
                vars_dict['temp_dir'] = temp_dir

            # call the run method with vars_dict
            proc_result = processor.run(vars_dict)

            # Handle different return types
            if isinstance(proc_result, bool):
                if proc_result:
                    func_result = True, f"Successfully processed {name}"
                else:
                    func_result = False, f"Processing failed for {name}"
            elif isinstance(proc_result, tuple) and len(proc_result) == 2:
                func_result = proc_result
            elif isinstance(proc_result, str):
                func_result = False, proc_result  # Assume string return is an error message
            else:
                func_result = True, f"Successfully processed {name}"

            if make_temp_dir:
                try:
                    os.rmdir(temp_dir)
                except OSError as e:
                    pass

            return func_result

        except Exception as e:
            error_msg = f"Error processing {name}: {str(e)}\n{traceback.format_exc()}"
            return False, error_msg

def main():
    processor = CoreProcessor()

    config_path = CONFIG_PATH
    results = processor.process_config(config_path)

    for name, success, message in results:
        status = "OK" if success else "FAILED"
        print(f"[{status}] {name}: {message}")

    if any(not success for _, success, _ in results):
        sys.exit(1)

if __name__ == "__main__":
    main()