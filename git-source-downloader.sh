#!/bin/bash

# Purpose:
# Given file that has a url for a git repository or a directory given
# a collection of those files, clone or fetch their contents into a
# root directory. Afterwards, if specified, build and install the
# repositories following commands specified in same file that lists
# the repository url.

set -e

build=false
dest=""
src=""

print_usage(){
    printf 'usage: [--build] <source> <destination>\n'
    printf '\n'
    printf ' --build\n'
    printf '            build and install after any updated sources are\n'
    printf '            fetched.\n'
    printf '\n'
    printf ' <destination>\n'
    printf '            parent directory for downloaded repositories.\n'
    printf '\n'
    printf ' <source>\n'
    printf '            File containing source url to pull from. File name\n'
    printf '            must end with ".source". If "--build" is specified,\n'
    printf '            then build instructions will be read from File as\n'
    printf '            well. If <source> is a directory, then all files in\n'
    printf '            contained within ending with ".source" will be\n'
    printf '            processed.\n'
    printf '\n'
    exit 1
}

check_args(){
    for arg in "$@"; do
        if echo "$arg" | grep -Eq "^--" ; then
            case "$arg" in
                "--build") build=true ;;
                *)
                    echo "Unknown option: $arg"
                    print_usage
                    ;;
            esac
        elif [ -z "$src" ] ; then
            # FIXME determine if $arg is rel or abs path
            # If not abs, prefix with $PWD
            if ! case "$arg" in /*) true;; *) false;; esac; then
                src="$PWD/"
            fi
            src="$src$arg"

        elif [ -z "$dest" ] ; then
            dest="$arg"

        else
            echo "Unexpected positional arguments after <destination>"
            print_usage
        fi
    done

    if [ -z "$src" ] || [ -z "$dest" ] ; then
        
        print_usage
    fi
}

git_fetch(){
    local dir="$1"
    local giturl="$2"
    local success=false

    if [ ! -d "$dir" ] ; then
        if git clone --depth 1 "$giturl" "$dir" ; then
            success=true
        fi

    else
        pushd "$dir"
        if git pull origin master ; then
            success=true
        fi
        popd
    fi

    if $success; then return 0; else return 1; fi
}

process_source_file(){
    local file="$1"
    local dir="$2/"
    local sourcePath="$dir$file"
    
    echo "$dir"
    if echo "$aFile" | grep -Eq "\.source"; then
        name=$(echo "$file" | sed -s 's/\.source//')
        url=$(head -n 1 "$sourcePath")
        
        echo "Working on $name"
        if git_fetch "$name" "$url" ; then
            if $build ; then
                pushd "$name"
                while IFS='' read -r line || [[ -n "$line" ]] ; do
                    eval "$line"
                done < <(tail -n +2 "$sourcePath")
                popd
            fi
        fi
        echo "Done with $name"
    fi
}

###### START HERE ######
check_args "$@"

mkdir -p "$dest"
cd "$dest"

if [ -d "$src" ] ; then
    for aFile in $(ls -1 "$src"); do
        process_source_file "$aFile" "$src"
    done

elif [ -f "$src" ] ; then
    process_source_file "$src"

else
    echo "<source> is neither a file or directory"
    print_usage
fi

# if $build ; then

#     if (( $(cat $updatedList | wc -l) > 0 )) ; then

        

# fi
