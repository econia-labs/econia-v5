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
    config = load_config()
    if set(config.values()) - set(NAMING_CONVENTIONS.keys()):
        print('Error: Unrecognized naming convention in file-name-conventions.yaml')
        print('Unrecognized naming conventions:', ', '.join(set(config.values()) - set(NAMING_CONVENTIONS.keys())))
        sys.exit(1)
    default_case = config.get('default', 'snake_case')  # Default case if not specified
    default_regex = NAMING_CONVENTIONS[default_case]

    cmd = ['git', 'ls-files']
    files = subprocess.check_output(cmd).decode().splitlines()

    errors = False
    for file_path in files:
        extension = '' if '.' not in file_path else file_path.split('.')[-1]
        case = config.get(extension, default_case)
        regex = NAMING_CONVENTIONS.get(case, re.compile(f'{default_regex}{extension}$'))

        if not check_file_naming(Path(file_path), regex):
            print(f'Error: {file_path} does not follow {case} naming convention')
            errors = True

    if errors:
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
