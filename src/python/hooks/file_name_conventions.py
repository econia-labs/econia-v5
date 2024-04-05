#!/usr/bin/env python3
# cspell:words colorama, LIGHTRED, LIGHTBLACK, LIGHTWHITE, LIGHTGREEN
import os
import re
import sys
from pathlib import Path

import yaml
from colorama import Fore, init

import utils

KEBAB_CASE = r"([a-z]+[a-z0-9\-]*)?"

CASE_REGEXES = {
    "camelCase": r"^([a-z]+[a-zA-Z0-9]*)?(\.\w+)?$",
    "snake_case": r"^(_*[a-z]+[a-z0-9_]*)?(\.\w+)?$",
    "kebab-case": rf"^{KEBAB_CASE}(\.\w+)?$",
    "PascalCase": r"^([A-Z]+[a-zA-Z0-9]*)?(\.\w+)?$",
    "UPPER_CASE": r"^(_*[A-Z]+[A-Z0-9_]*)?(\.\w+)?$",
    "*": r"^.*$",
}

ERROR_STRING = Fore.RED + "ERROR:" + Fore.RESET
WARNING_STRING = Fore.LIGHTRED_EX + "WARNING:" + Fore.RESET

root = utils.get_git_root()


def load_config(p: Path) -> dict:
    if p.exists():
        with open(p, "r") as file:
            return dict(yaml.safe_load(file))
    else:
        print(f"{ERROR_STRING} {p} not found.")
        sys.exit(1)
    return {}


def check_files(files: list[str], cfg_path: Path) -> set[Path]:
    file_names_config = load_config(cfg_path)
    default_case = file_names_config.get("default", None)
    if not default_case:
        print(ERROR_STRING, end=" ")
        print("No default case defined in file-name-conventions.yaml")
        sys.exit(1)
    filetypes = file_names_config.get("filetypes", {})
    if len(filetypes) == 0:
        warning_msg = f"No filetypes defined in {cfg_path}"
        print(WARNING_STRING, warning_msg)
    ignore_files = set(file_names_config.get("ignore_files", {}))

    # Validate the user supplied naming conventions against known conventions.
    user_supplied_cases = set(filetypes.values()).union({default_case})
    unrecognized_cases = user_supplied_cases - set(CASE_REGEXES.keys())
    if unrecognized_cases:
        print(ERROR_STRING, end=" ")
        print("Unrecognized case in file-name-conventions.yaml")
        print("Unrecognized cases:", ", ".join(unrecognized_cases))
        sys.exit(1)

    # Check the user-supplied file name conventions against each file.
    invalid_files: set[Path] = set()
    for file_path in map(Path, files):
        # Get the file extension and handle the case where there isn't
        # one. Then get the case by its extension and the regex by its case.
        extension = file_path.suffix.split(".")[-1]
        case = filetypes.get(extension, default_case)
        regex = CASE_REGEXES.get(case, default_case)

        filename = Path(file_path).name
        if filename in ignore_files:
            continue

        # Check the file name as a Path object against the regex pattern,
        # then pretty print it out if it doesn't match.
        if not re.match(regex, filename):
            rel_file_dir = Path(os.path.dirname(file_path)).relative_to(root)
            file_dir = str(rel_file_dir) + "/"
            file_name = os.path.basename(file_path)
            colored_dir = Fore.LIGHTBLACK_EX + file_dir
            colored_fp = Fore.LIGHTWHITE_EX + file_name
            colored_case = Fore.YELLOW + case
            colored_default_msg = Fore.LIGHTBLACK_EX + "(default)"
            print(ERROR_STRING, end=" ")
            print(
                f"{colored_dir}{colored_fp}",
                f"{Fore.LIGHTBLACK_EX}is not",
                colored_case,
                colored_default_msg,
            )
            invalid_files.add(file_path)
    return invalid_files


def check_folders(files: list[str], cfg_path: Path) -> set[Path]:
    folder_names_config = load_config(cfg_path)
    default_case = folder_names_config.get("default", None)
    if not default_case:
        print(ERROR_STRING, end=" ")
        print("No default case defined in folder-name-conventions.yaml")
        sys.exit(1)

    ignore_folders = set()
    for folder in folder_names_config.get("ignore_folders", {}):
        abs_folder = os.path.join(root, folder)
        if not os.path.exists(abs_folder):
            print(
                ERROR_STRING,
                f"{Fore.CYAN}{abs_folder}{Fore.RESET}",
                "in `ignore_folders` does not exist.",
            )
            sys.exit(1)
        if not os.path.isdir(abs_folder):
            print(
                ERROR_STRING,
                f"{Fore.CYAN}{abs_folder}{Fore.RESET}",
                "in `ignore_folders` is not a directory.",
            )
            sys.exit(1)
        ignore_folders.add(Path(abs_folder))

    file_paths = set(Path(f) for f in files)

    directories = set()
    root_path = Path(root)

    for fp in file_paths:
        # Add the filepath to the set of parent directories if it itself
        # is a directory.
        abs_fp = Path(os.path.join(root, str(fp)))
        parents = list(fp.parents) + list([abs_fp] if abs_fp.is_dir() else [])

        for parent in parents:
            in_repo = parent.is_relative_to(root_path)
            ignored = parent in ignore_folders
            if in_repo and not ignored:
                directories.add(parent.relative_to(root_path))

    if Path(".") in directories:
        directories.remove(Path("."))

    # Verify that each directory name remaining adheres to naming conventions.
    # If not, pretty print out the directory name and the error message.
    invalid_folders: set[Path] = set()
    for directory in sorted(directories):
        folder_name = directory.parts[-1]
        if not re.match(KEBAB_CASE + "$", folder_name):
            # The path without the folder name.
            base_path = ""
            abs_parent = Path(os.path.join(root_path, directory.parent))
            if abs_parent != root_path:
                base_path = str(abs_parent.relative_to(root_path))

            sep = os.sep if base_path else ""
            colored_base_path = Fore.LIGHTWHITE_EX + base_path + sep
            colored_folder_name = Fore.LIGHTBLUE_EX + folder_name

            print(ERROR_STRING, end=" ")
            print(
                colored_base_path + colored_folder_name,
                f"{Fore.LIGHTBLACK_EX}is not",
                f"{Fore.YELLOW}kebab-case",
            )
            invalid_folders.add(directory)
    return invalid_folders


def result_message(paths: set[Path], path_type: str) -> str:
    to_be = "is" if len(paths) == 1 else "are"
    plurality = " that does" if len(paths) == 1 else "s that do"
    return " ".join(
        [
            f"There {to_be}",
            f"{Fore.LIGHTBLUE_EX}{len(paths)}{Fore.RESET}",
            f"{path_type} name{plurality} not adhere to naming conventions.",
        ]
    )


def main():
    init(autoreset=True)
    # The files are passed as arguments from the pre-commit hook.
    files = sys.argv[1:]

    files_cfg_path = os.path.join(root, "cfg/file-name-conventions.yaml")
    folders_cfg_path = os.path.join(root, "cfg/folder-name-conventions.yaml")
    invalid_files = check_files(files, Path(files_cfg_path))
    invalid_folders = check_folders(files, Path(folders_cfg_path))

    invalid_folders = list(invalid_folders)[-1:]

    if invalid_files:
        msg = result_message(invalid_files, "file")
        print(msg)
    if invalid_folders:
        msg = result_message(invalid_folders, "folder")
        print(msg)

    if invalid_files or invalid_folders:
        sys.exit(1)

    print()
    print(Fore.LIGHTGREEN_EX, end="")
    print("All file and folder names adhere to naming conventions!")
    sys.exit(0)


if __name__ == "__main__":
    main()
