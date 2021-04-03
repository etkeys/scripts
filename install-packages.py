#!/usr/bin/env python3

import argparse
import csv
from enum import Enum
import itertools
import logging
from os import geteuid, path
from string import Template
import subprocess
import time

logger = logging.getLogger(__name__)

class ExitCodes(Enum):
    SUCCESS = 0
    GENERAL_ERROR = 1
    INVALID_USER = 2
    USER_REQUESTED = 250

class InstallCommands():
    APT = Template('apt-get install -y $package $additional_options')
    PIP = Template('yes | pip install -q $package')
    SNAP = Template('snap install $package $additional_options')

    @staticmethod
    def get_command(rec):
        provider = rec['provider']
        cmd = ''
        if provider == 'apt':
            cmd = InstallCommands.APT.substitute(rec)
        elif provider == 'pip':
            cmd = InstallCommands.PIP.substitute(rec)
        elif provider == 'snap':
            cmd = InstallCommands.SNAP.substitute(rec)
        return cmd

def user_is_root():
    return (geteuid() == 0)

def get_csv_data(fp):
    ret = [r for r in csv.DictReader(fp)]
    for row in ret:
        row['tags'] = row['tags'].split(';')
    return ret

def filter_data_to_requested_tags(data, requested_tags):
    def is_package_tag_requested(data_item):
        intersect = [value for value in data_item['tags'] if value in requested_tags]
        return len(intersect) > 0
    
    ret = filter(is_package_tag_requested, data)
    return ret

def compute_elapsed_time(start):
    end = time.perf_counter()
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    ret = f'{int(hours):0>2}:{int(minutes):0>2}:{int(seconds):0>2}' 
    return ret

def perform_install(data, options):
    start_time = time.perf_counter()
    data_count_orig = len(data)
    data = list(filter_data_to_requested_tags(data, options.tags))
    data_count_try = len(data)

    print(f'Installing {data_count_try} of {data_count_orig} packages with tags {", ".join(sorted(options.tags))}...')

    for num, item in enumerate(data, start=1):
        elapsed_time = compute_elapsed_time(start_time)
        cmd = InstallCommands.get_command(item)

        print(f'[{elapsed_time}]({num}/{data_count_try}) {item["package"]}')        

        if options.simulate:
            print(cmd)
            time.sleep(1.27)
        else:
            subprocess.run(
                cmd,
                check=True,
                encoding='utf-8',
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)

def main(options):
    if not options.simulate and not user_is_root():
        logger.error('Not running as root user, aborting.')
        exit(ExitCodes.INVALID_USER)

    data = get_csv_data(options.file)
    if options.list_tags:
        data = sorted(
            set(
                itertools.chain.from_iterable(
                    map(lambda x: x['tags'], data))))

        for item in data:
            print(item)
    else:
        if len(options.tags) < 2 and options.tags[0] == 'any':
            logger.warning('Tags contains only "any". Only packages with "any" tag will be installed.')
        
        perform_install(data, options)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.set_defaults(allow_abbrev=False)

    # optionals
    parser.add_argument(
        '-f', '--file',
        default='packages.csv',
        dest='file',
        metavar='FILE',
        type=argparse.FileType('r'),
        help='Path to a csv file that contains list of packages to install'
    )
    parser.add_argument(
        '-l', '--list-tags',
        action='store_true',
        help='Only show what tags are present in the provided list file'
    )
    parser.add_argument(
        '--no-any-tag',
        action='store_true',
        help='Exclude "any" from the tags of packages to install'
    )
    parser.add_argument(
        '--simulate',
        action='store_true',
        help='Print what would be done, but don\'t actually do anything'
    )
    parser.add_argument(
        '-t', '--tags',
        dest='tags',
        metavar='TAG',
        nargs='+',
        help='Tags assoicated with packages to install (in addition to "any")'
    )

    options = parser.parse_args()
    if not options.no_any_tag:
        options.tags.append('any')
    if len(options.tags) < 1:
        print('No tags were given. Nothing to do.')
        exit(ExitCodes.SUCCESS)
    main(options)
