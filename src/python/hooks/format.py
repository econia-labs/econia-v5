#!/usr/bin/env python3
# cspell:words autoflake, colorama, LIGHTBLACK, LIGHTWHITE, LIGHTYELLOW

import os
import subprocess

from colorama import Fore, init

import utils


def main():
    init(autoreset=True)

    all_files = utils.git_ls_files(abs_paths=True)
    list(filter(utils.is_python_file, all_files))

    changed_files_before = utils.get_changed_files()

    autoflake_args = [
        "-i",
        "--remove-all-unused-imports",
        "--remove-unused-variables",
        "--ignore-init-module-imports",
    ]

    cmd_and_args = {
        "poetry run autoflake": (
            " ".join(autoflake_args),
            utils.is_python_file,
        ),
        "poetry run black": ("--color", utils.is_python_file),
        "poetry run isort": ("", utils.is_python_file),
        "poetry run flake8": ("", utils.is_python_file),
        "poetry run mypy": ("", utils.is_python_file),
        "poetry run python -m file_name_conventions": ("", lambda x: True),
    }

    return_statuses = {k: "" for k in cmd_and_args.keys()}

    for cmd, arg_and_filter in cmd_and_args.items():
        args, filter_func = arg_and_filter
        # Filter with the `filter_func` and only include files that still
        # exist, since `git ls-files` includes directories and deleted files.
        filtered_files = list(
            filter(lambda x: filter_func(x) and os.path.isfile(x), all_files)
        )
        full_cmd = list(
            filter(
                utils.is_non_empty_string,
                [*cmd.split(" "), *args.split(" "), *filtered_files],
            )
        )

        print(f"{Fore.LIGHTBLACK_EX + cmd + '.'*(90 - len(cmd))}")
        process = subprocess.Popen(
            full_cmd,
        )
        stdout, stderr = process.communicate()
        print()
        return_status = "Success" if process.returncode == 0 else "Failure"
        return_statuses[cmd] = return_status

    changed_files_after = utils.get_changed_files()
    changed_files = changed_files_after - changed_files_before

    # Pretty print the return statuses for each command.
    len_longest_cmd = max([len(c) for c in cmd_and_args.keys()])
    for cmd, return_status in return_statuses.items():
        return_emoji = "✅" if return_status == "Success" else "❌"
        print(
            Fore.LIGHTWHITE_EX + cmd,
            "." * (len_longest_cmd + 4 - len(cmd)),
            return_emoji,
        )

    # Print the files that have uncommitted changes.
    # NOTE: Files that had previously uncommitted changes but have been
    # modified by the commands above will not be included here.
    changed_file_msg = ""
    if changed_files:
        msg_color = Fore.LIGHTYELLOW_EX
        changed_file_msg = "The following files now have uncommitted changes:"
    else:
        msg_color = Fore.LIGHTBLACK_EX
        changed_file_msg = "There are no new uncommitted files."
    print(msg_color + changed_file_msg)
    for file in changed_files:
        print(file)

    print()


if __name__ == "__main__":
    main()
