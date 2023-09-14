#!/usr/bin/env python3
import argparse
from csv import DictReader
from datetime import datetime, timedelta
import os
import random
import subprocess
from time import sleep

_DEFAULT_DELAY_SECONDS = 211 # 3 minutes 31 seconds

_DEFAULT_DELAY_LEEWAY_SECONDS = 17

_SCRIPT_DESCRIPTION = """
Read CSV file and use youtube-dl to download videos from specified URLs, extract
the audio, and save the audio as mp3 file at the specified location with the specified
name.
"""

_SCRIPT_EPILOG = """
Expected columns of CSV are {url,name,dir}. "url" is the URL address of
the video to download. "name" is the desired name of the final mp3 file (without
the extension). "dir" is the directory to place the final mp3 file. If "dir" begins
with '@', the path that follows is prefixed with '$HOME/Music'. For example,
if "dir" is '@Dubstep' the actual path would be '$HOME/Music/Dubstep'. If "dir"
does not being with '@', then the path is check if it is an absolute path or
relative. If the directory specified by "dir" does not exist, it is created.
"""

def calculate_delay_time(delay_sec, leeway_sec):
    leeway_op = random.choice(['+', '-'])
    leeway_val = random.randint(0, leeway_sec)

    if leeway_op == '-' and leeway_val > 0:
        leeway_val = leeway_val * -1

    return timedelta(seconds=delay_sec + leeway_val)


def download_item(url, final_name, final_dir):
    try:
        if not os.path.exists(final_dir):
            os.makedirs(final_dir)

        ret = subprocess.run(
            [
                'yt-dlp',
                '--restrict-filename',
                '--extract-audio',
                '--audio-format', 'mp3',
                url,
                '--exec', f"mv {{}} {os.path.join(final_dir, final_name)}.mp3"
            ]
        )
        return (
            ret.returncode == 0,
            None if ret.returncode == 0 else 'Download failure. See application text.'
        )
    except Exception as e:
        return (False, f"Download failure. {e}")

def get_real_final_dir(input):
    if input.startswith('@'):
        # substitue "@" with the default root directory: $HOME/Music
        home = os.environ.get('HOME')
        return os.path.join(home, 'Music', input[1:])

    elif os.path.isabs(input):
        # provided path is an absolut path, just return it.
        return input
    else:
        # path is relative to our working directory. Prepend the working directory
        # then return the result.
        raise NotImplementedError

def main():
    parser = argparse.ArgumentParser(
        description=_SCRIPT_DESCRIPTION,
        epilog=_SCRIPT_EPILOG)
    parser.set_defaults(allow_abbrev=False)

    # positionals
    parser.add_argument(
        'File',
        metavar='FILE',
        type=argparse.FileType('r'),
        help='The CSV file to read inputs from.'
    )

    # flags
    parser.add_argument(
        '--delay',
        # type=int,
        dest='delay',
        action='store_const',
        default=_DEFAULT_DELAY_SECONDS,
        help='Number of seconds to wait between each download (for the paranoid).'
    )

    parser.add_argument(
        '--delay-leeway',
        # type=int,
        dest='delay_leeway',
        action='store_const',
        default=_DEFAULT_DELAY_LEEWAY_SECONDS,
        help='Number of seconds higher or lower than --delay to make the wait time somewhat inconsistant.'
    )

    args = parser.parse_args()

    random.seed()

    data = [r for r in DictReader(args.File)]
    for idx, row in enumerate(data):
        url = row['url']
        final_name = row['name']
        final_dir = row['dir']
        final_dir = get_real_final_dir(final_dir)

        print(f"[{idx + 1}/{len(data)}] Downloading {final_name} ({url}) to {final_dir}.")

        success, ex = download_item(url, final_name, final_dir)

        if not success:
            with open('youtubedl-download-mp3.errors', 'a') as f:
                f.writelines([f"{final_name} ({url}): {ex}"])

        if args.delay > 0 and idx < (len(data) - 1):
            wait_time = calculate_delay_time(args.delay, args.delay_leeway)
            print(f"Current time: {datetime.now().strftime('%H:%M:%S')}")
            print(f"Sleeping until: {(datetime.now() + wait_time).strftime('%H:%M:%S')}")
            sleep(wait_time.seconds)

if __name__ == '__main__':
    main()
