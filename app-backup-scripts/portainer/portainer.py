import requests
from typing import Dict, Any, Tuple

class Handler:
    def _get_backup(self, api_url_root: str, password: str, jwt: str) -> Tuple[bytes, str]:
        """
        Request backup from Portainer API.
        
        Returns a tuple of (backup_data, message).
        """
        try:
            print("Requesting backup from Portainer API...")

            headers = {
                "Authorization": f"Bearer {jwt}"
            }
            # We have to provide the password again to get the backup. I guess it's for security reasons.
            post_data = {
                "Password": f"{password}"
            }
            url = f"{api_url_root}/backup"

            response = requests.post(url, headers=headers, json=post_data, timeout=600, verify=False)

            if response.status_code != 200:
                return None, f"Failed to get backup: HTTP {response.status_code} - {response.text}"

            print("Backup obtained successfully.")
            return response.content, None

        except Exception as e:
            return None, f"Exception occurred while obtaining backup: {str(e)}"

    def _get_jwt_token(self, api_url_root: str, username: str, password: str) -> Tuple[str, str]:
        """
        Obtain JWT token from Portainer API.
        
        Returns a tuple of (token, message).
        """
        try:
            print("Obtaining JWT token from Portainer API...")

            post_data = {
                "Username": username,
                "Password": password
            }
            url = f"{api_url_root}/auth"

            response = requests.post(url, json=post_data, timeout=30, verify=False)

            if response.status_code != 200:
                return None, f"Failed to get JWT token: HTTP {response.status_code} - {response.text}"

            jwt = response.json().get('jwt', None)
            
            if not jwt:
                return None, "JWT token not found in response."

            print("Obtained JWT token successfully.")
            return jwt, None

        except Exception as e:
            return None, f"Exception occurred while obtaining JWT token: {str(e)}"

    def run(self, vars_dict: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Process Portainer backup with given variables.
        
        Returns a tuple indicating success and a message.
        """
        try:
            backup_dir = vars_dict.get('backup_dir', None)
            tar_file = vars_dict.get('tar_file', None)
            username = vars_dict.get('username', None)
            password = vars_dict.get('password', None)
            api_url_root = vars_dict.get('api_url_root', None)

            # From caller
            if not backup_dir:
                return False, "backup_dir variable is missing."
            if not tar_file:
                return False, "tar_file variable is missing."

            # From config.yml
            if not api_url_root:
                return False, "'api_url_root' not defined."
            if not username:
                return False, "'username' not defined."
            if not password:
                return False, "'password' not defined."

            jwt, fail_message = self._get_jwt_token(api_url_root, username, password)
            if fail_message:
                return False, fail_message

            backup_data, fail_message = self._get_backup(api_url_root, password, jwt)
            if fail_message:
                return False, fail_message

            tar_path = f"{backup_dir}/{tar_file}"
            with open(tar_path, 'wb') as f:
                f.write(backup_data)

            print(f"Backup saved to {tar_path}.")
            return True, f"Backup createdd successfully."

        except Exception as e:
            return False, f"Exception occurred during backup process: {str(e)}"

