#!/usr/bin/env python3

import argparse
import json
import os
import re
import shutil
import subprocess
import unicodedata

_SCRIPT_DESCRIPTION = """
Takes an audiobook file in m4b format and breaks it into smaller mp3 files
based on chapters.
"""

_SCRIPT_EPILOG = """
Chapters are determined based on makers from m4b file. MP3 files will be placed
in a subdirectory where the input file is located.
"""

class Chapter():

    def __init__(self, raw_obj):
        self.track = raw_obj["id"] + 1
        self.start_time = raw_obj["start_time"]
        self.end_time = raw_obj["end_time"]
        self.metadata_title = raw_obj["tags"]["title"]

    def __repr__(self):
        return f"(Track={self.track};Title={self.metadata_title};Start={self.start_time};End={self.end_time};File={self.file_name})"

    def set_file_name(self, count_chapters):
        if count_chapters < 99:
            index = f"{self.track:02}"
        elif count_chapters < 999:
            index = f"{self.track:03}"
        else:
            raise NotImplemented("Indexing chapters greater than 999 not implemented.")

        # Normalize string to use for a filename. Based on Django code.
        # https://stackoverflow.com/a/295466
        temp_value = f"{index}-{self.metadata_title}"
        temp_value = unicodedata.normalize("NFKD", temp_value).encode("ascii", "ignore").decode("ascii")
        temp_value = re.sub(r"[^\w\s-]", "", temp_value.lower())
        temp_value = re.sub(r"[-\s]+", "-", temp_value).strip("-_")
        self.file_name = f"{temp_value}.mp3"

def get_chapters(input_file):
    ret = subprocess.run(
        [
            "ffprobe",
            "-i", input_file,
            "-print_format", "json",
            "-show_chapters"
        ],
        stdout=subprocess.PIPE
    )

    ret.check_returncode()

    j = json.loads(ret.stdout.decode('utf-8'))
    #print(j)
    chapters = []
    for raw_chapter in j["chapters"]:
        #print(raw_chapter)
        chapters.append(Chapter(raw_chapter))

    for c in chapters:
        c.set_file_name(len(chapters))

    return chapters

def create_output_directory(input_file):
    # we will create a subdirectory in the same directory as the input file.
    parent_dir = os.path.dirname(input_file)
    # print(f"Parent Directory={parent_dir}")

    out_dir = os.path.join(parent_dir, "mp3")
    # print(f"Output dir={out_dir}")

    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)

    return out_dir

def split_input_into_chapters(input_file, author, book_title, chapters):
    out_dir = create_output_directory(input_file)
    count_chapters = len(chapters)
    for idx, chapter in enumerate(chapters):
        print(f"Creating chapter: {chapter.file_name} ({idx + 1}/{count_chapters})")
        ret = subprocess.run(
            [
                "ffmpeg",
                "-i", input_file,
                "-vn", "-c", "libmp3lame",
                "-ss", chapter.start_time,
                "-to", chapter.end_time,
                "-metadata", f"title={chapter.metadata_title}",
                "-metadata", f"track={chapter.track}",
                "-metadata", f"artist={author}",
                "-metadata", f"album={book_title}",
                "-map_metadata", "0",
                "-id3v2_version", "3",
                f"{os.path.join(out_dir, chapter.file_name)}"
            ],
            stderr=subprocess.DEVNULL
        )

        ret.check_returncode()

        print(F"Done with chapter: {chapter.file_name}")


def main(cli_args):
    chapters = get_chapters(cli_args.input_file)
    # for c in chapters:
    #     print(c)
    split_input_into_chapters(
        cli_args.input_file,
        cli_args.author,
        cli_args.book_title,
        chapters)


if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(
        description=_SCRIPT_DESCRIPTION,
        epilog=_SCRIPT_EPILOG
    )

    # positionals
    arg_parser.add_argument(
        "input_file",
        metavar="INPUT_FILE",
        help="The m4b files to break into smaller files."
    )

    # flags
    arg_parser.add_argument(
        "--author",
        dest="author",
        required=True,
        help="The book's author."
    )

    arg_parser.add_argument(
        "--title",
        dest="book_title",
        required=True,
        help="The title of the book."
    )

    args = arg_parser.parse_args()
    main(args)

"""
ffprobe -i 'Fourth Wing: Empyrean, Book 1 [BOBVD25SYT].m4b -print_format json \
    -show_chapters

ffmpeg -i 'Fourth Wing: Empyrean, Book 1 [BOBVD25SYT].m4b' -vn -c libmp3lame \
    -ss "<start_time>" -to "<end_time>" -metadata title="<tags>.<title>" \
    -metadata track="<id> + 1" -map_metadata 0 -id3v2_version 3 \
    "<output_file_name>.mp3"

For <output_file_name>, prefix with 2 or 3 digits based on how many chapters
there are. So if there are 48 chapters, then the prefix will be "00" which
increments for each FILE that is produced.

May also want to pass "-metadata album" and "-metadata artist" to pass in the
correct values for those as well.
"""