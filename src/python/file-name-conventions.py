#!/usr/bin/env python3
import yaml
import subprocess
import re
import sys
from pathlib import Path

# Naming conventions
NAMING_CONVENTIONS = {
    'camelCase': r'^([a-z]+[a-zA-Z0-9]*)?\.',
    'snake_case': r'^([a-z]+[a-z0-9_]*)?\.',
    'kebab-case': r'^([a-z]+[a-z0-9\-]*)?\.',
    'PascalCase': r'^([A-Z]+[a-zA-Z0-9]*)?\.',
    'UPPER_CASE': r'^([A-Z]+[A-Z0-9_]*)?\.',
    '*': r'^.*\.'
}

def load_config():
    config_path = Path('cfg/file-name-conventions.yaml')
    if config_path.exists():
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    return {}

def check_file_naming(file_path, pattern):
    return re.match(pattern, file_path.name)

def main():
    config = load_config()  # Load the configuration
    default_case = config.get('default', 'snake_case')  # Get the default case
    filetypes = config.get('filetypes', {})  # Get the file type specific conventions

    # Validate the naming conventions against known conventions
    all_conventions = set(filetypes.values()).union({default_case})
    unrecognized_conventions = all_conventions - set(NAMING_CONVENTIONS.keys())
    if unrecognized_conventions:
        print('Error: Unrecognized naming convention in file-name-conventions.yaml')
        print('Unrecognized naming conventions:', ', '.join(unrecognized_conventions))
        sys.exit(1)

    # Retrieve all tracked files
    cmd = ['git', 'ls-files']
    files = subprocess.check_output(cmd).decode().splitlines()

    errors = False
    print('Duplicate files in `git ls-files` output:', len(files) - len(set(files)))
    i = 0
    for file_path in files:
        extension = file_path.split('.')[-1] if '.' in file_path else ''
        case = filetypes.get(extension, default_case)
        regex = NAMING_CONVENTIONS.get(case, default_case)

        if not check_file_naming(Path(file_path), regex):
            print(f'i: {i} -> Error: {file_path} does not follow {case} naming convention')
            errors = True
        i += 1

    if errors:
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
