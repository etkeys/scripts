#!/usr/bin/env python3
import argparse
from csv import DictReader
from random import choice

_SCRIPT_DESCRIPTION = """
Given csv file containing the names of scented waxes in the format of
{name,tags}, script will randomly choose an item from the list. Can pass
specific tags to the script to limit the options to pick from.
"""

def filter_to_requested_tags(data, requested_tags):
    def is_tag_requested(data_item):
        # set intersection
        matches = (requested_tags & set(data_item["tags"]))
        return len(matches) > 0

    return data if "*" in requested_tags else filter(is_tag_requested, data)

def main():
    parser = argparse.ArgumentParser(description=_SCRIPT_DESCRIPTION)
    parser.set_defaults(allow_abbrev=False)
    # positionals
    parser.add_argument(
        "tags",
        default=["*"],
        metavar="TAG",
        nargs="*",
        help="the tag(s) of items to pick from.")
    # flags
    parser.add_argument(
        "--data",
        dest="file",
        required=True,
        type=argparse.FileType("r"),
        help="path to the csv file containing items to pick from.")
    args = parser.parse_args()

    data = [r for r in DictReader(args.file)]
    for row in data:
        row["tags"] = row["tags"].split(";")

    data = list(filter_to_requested_tags(data, set(args.tags)))
    pick = dict(choice(data))

    print(f"Name: {pick['name']}")
    print(f"Tags: {pick['tags']}")

if __name__ == "__main__":
    main()