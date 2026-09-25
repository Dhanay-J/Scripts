# Include this in ~/.bashrc
# While using / (divide) use space. [Eg. 5 / 2]
# Intercept unrecognized commands to catch math expressions
command_not_found_handle() {
    # Combine the original command and all its arguments into one string
    local cmd="$*"

    # FIXED REGEX: The hyphen (-) is placed at the end so it doesn't create a broken range
    if [[ "$cmd" =~ ^[0-9[:space:]\+\*/%\(\)\.-]+$ ]]; then
        # Ensure it contains at least one math operator so a single number doesn't trigger it
        if [[ "$cmd" =~ [\+\*/%-] ]]; then
            # Execute with Python and print the result
            python3 -c "print($cmd)" 2>/dev/null
            return $?
        fi
    fi

    # Fall back to default Ubuntu handler if it's not a math expression
    if [ -x /usr/lib/command-not-found ]; then
        /usr/lib/command-not-found -- "$1"
        return $?
    else
        echo "$1: command not found" >&2
        return 127
    fi
}
