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


def check_file_naming(file_path, pattern):
    return re.match(pattern, file_path.name)


def main():
    config = load_config()
    default_case = config.get("default", "snake_case")
    filetypes = config.get("filetypes", {})

    # Validate the user supplied naming conventions against known conventions.
    user_supplied_cases = set(filetypes.values()).union({default_case})
    unrecognized_cases = user_supplied_cases - set(CASE_REGEXES.keys())
    if unrecognized_cases:
        print("Error: Unrecognized case in file-name-conventions.yaml")
        print("Unrecognized cases:", ", ".join(unrecognized_cases))
        sys.exit(1)

    files = sys.argv[1:]

    errors = False
    for file_path in files:
        extension = file_path.split(".")[-1] if "." in file_path else ""
        case = filetypes.get(extension, default_case)
        regex = CASE_REGEXES.get(case, default_case)

        print(f"Checking {file_path} for {case} naming convention")

        if not check_file_naming(Path(file_path), regex):
            print(f"Error: {file_path} is not {case}.")
            errors = True

    if errors:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
