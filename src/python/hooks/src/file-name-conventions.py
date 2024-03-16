#!/usr/bin/env python3
import re
import sys
from pathlib import Path

import yaml

CASE_REGEXES = {
    "camelCase": r"^([a-z]+[a-zA-Z0-9]*)?\.",
    "snake_case": r"^([a-z]+[a-z0-9_]*)?\.",
    "kebab-case": r"^([a-z]+[a-z0-9\-]*)?\.",
    "PascalCase": r"^([A-Z]+[a-zA-Z0-9]*)?\.",
    "UPPER_CASE": r"^([A-Z]+[A-Z0-9_]*)?\.",
    "*": r"^.*\.",
}


def load_config():
    config_path = Path("cfg/file-name-conventions.yaml")
    if config_path.exists():
        with open(config_path, "r") as file:
            return yaml.safe_load(file)
    return {}


def main():
    config = load_config()
    default_case = config.get("default", "snake_case")
    filetypes = config.get("filetypes", {})
    exceptions = set(config.get("exceptions", {}))

    # Validate the user supplied naming conventions against known conventions.
    user_supplied_cases = set(filetypes.values()).union({default_case})
    unrecognized_cases = user_supplied_cases - set(CASE_REGEXES.keys())
    if unrecognized_cases:
        print("Error: Unrecognized case in file-name-conventions.yaml")
        print("Unrecognized cases:", ", ".join(unrecognized_cases))
        sys.exit(1)

    # The files are passed as arguments from the pre-commit hook.
    files = sys.argv[1:]

    # Check the user-supplied file name conventions against each file.
    invalid_file_names = False
    for file_path in files:
        # Get the file extension and handle the case where there isn't
        # one. Then get the case by its extension and the regex by its case.
        extension = file_path.split(".")[-1] if "." in file_path else ""
        case = filetypes.get(extension, default_case)
        regex = CASE_REGEXES.get(case, default_case)

        filename = Path(file_path).name
        if filename in exceptions:
            print(f"Skipping {file_path} due to exception.")
            continue

        print(f"Checking {file_path} for {case} naming convention")

        # Check the file name as a Path object against the regex pattern.
        if not re.match(regex, filename):
            print(f"Error: {file_path} is not {case}.")
            invalid_file_names = True

    if invalid_file_names:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
