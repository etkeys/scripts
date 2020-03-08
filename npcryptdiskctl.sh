#!/bin/bash

# usage:
# npcryptdiskctl start [crypt_name ... |[all]]
# npcryptdiskctl stop [crypt_name ... |[all]]
# npcryptdiskctl help [crypt_name ... |[all]]

CMD="$1"; shift
CRYPTS=(${@:-"all"})

EXIT_SUCCESS=0
EXIT_BAD_ARGS=1
EXIT_BAD_CRYPT_ACTION=2
EXIT_BAD_EUID=3

TRUE=0
FALSE=1

print_usage(){
    if ! [ -z "$1" ] ; then
        printf "$1\n"
    fi
    printf "usage:\n"
    printf "\tnpcryptdiskctl {start|stop|help} [<crypt_name>|[all]]\n";

    exit $EXIT_BAD_ARGS
}

is_in_crypttab(){
    grep -q "^$1" /etc/crypttab
    return $?
}

can_inactivate(){
    cryptsetup status "$1" | grep -q "$1 is inactive"
    if [ $? -eq $TRUE ] ; then
        return $FALSE
    else
        return $TRUE
    fi
}

can_activate(){
    if can_inactivate "$1" ; then
        return $FALSE
    else
        return $TRUE
    fi
}

if [ "$EUID" -ne $TRUE ] ; then
    echo "Not running as root, exiting."
    exit $EXIT_BAD_EUID
fi

# Was valid command given?
if [ -z "$CMD" ] ; then
    print_usage "[E] No command specified."
elif [ "$CMD" = "help" ] ; then
    print_usage
elif [ "$CMD" != "start" ] && [ "$CMD" != "stop" ] ; then
    print_usage "Unknown command: \"$CMD\""
fi

# If all was given, populate crypttab targets
if [ ${CRYPTS[0]} = "all" ] ; then
    CRYPTS=($(sed 'N;s/\n/ /g' /etc/npcryptdiskctl/npcryptdiskctl.targets))
fi

RET_CODE=$EXIT_SUCCESS
for c in "${CRYPTS[@]}" ; do
    if is_in_crypttab "$c" ; then
        echo "$c found in crypttab, taking action..."
        case $CMD in
            "start") 
                if can_activate "$c" ; then
                    cryptdisks_start "$c"

                    if [ $? -ne $TRUE ] ; then
                        echo "something went wrong..."
                        RET_CODE=$EXIT_BAD_CRYPT_ACTION
                    fi
                else
                    echo "$c is already active, skipping."
                fi
                ;;
            "stop") 
                if can_inactivate "$c" ; then
                    cryptdisks_stop "$c"

                    if [ $? -ne $TRUE ] ; then
                        echo "something went wrong!"
                        RET_CODE=$EXIT_BAD_CRYPT_ACTION
                    fi
                else
                    echo "$c is already stopped, skipping."
                fi
                ;;
        esac
    else
        echo "$c not found in crypttab, ignoring..."
    fi
done

exit $RET_CODE


