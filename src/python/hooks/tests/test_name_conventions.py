# cspell:words ignoredfolder, badfolder
import os
from pathlib import Path

import file_name_conventions as fnc
import utils

root = utils.get_git_root()

FILES_CFG_PATH = "src/python/hooks/tests/test-file-conventions.yaml"
FOLDER_CFG_PATH = "src/python/hooks/tests/test-folder-conventions.yaml"


def abs_str_path(fp: str) -> str:
    return os.path.join(root, fp)


def abs_path(fp: str) -> Path:
    return Path(abs_str_path(fp))


def get_abs_cfg_paths(file_path: str, folder_path: str) -> tuple[Path, Path]:
    files_cfg = abs_str_path(file_path)
    folder_cfg = abs_str_path(folder_path)
    assert os.path.isfile(files_cfg)
    assert os.path.isfile(folder_cfg)
    return (Path(files_cfg), Path(folder_cfg))


def test_check_both():
    fi_path, fo_path = get_abs_cfg_paths(FILES_CFG_PATH, FOLDER_CFG_PATH)

    res = set()
    fp = "src/python/hooks/some_file.py"
    assert res == fnc.check_files([fp], fi_path)
    assert res == fnc.check_folders([fp], fo_path)


def test_config_values():
    fi_path, fo_path = get_abs_cfg_paths(FILES_CFG_PATH, FOLDER_CFG_PATH)

    file_cfg = fnc.load_config(fi_path)
    assert file_cfg["default"] == "kebab-case"
    assert file_cfg["filetypes"]["ts"] == "kebab-case"
    assert file_cfg["filetypes"]["py"] == "snake_case"
    assert file_cfg["filetypes"]["rs"] == "snake_case"
    assert file_cfg["filetypes"]["md"] == "*"
    assert file_cfg["filetypes"]["toml"] == "PascalCase"

    folder_cfg = fnc.load_config(fo_path)
    assert folder_cfg["default"] == "kebab-case"
    ignored_folders = folder_cfg["ignore_folders"]
    assert "src/python/hooks/tests/.ignoredfolder" in ignored_folders


# Note that the file paths passed into `check_files` and `check_folders`
# are not checked for existence since we assume `pre-commit` will not
# pass in non-existent file paths.
# The reason we check this edge case is because it's possible to pass in
# an empty directory to GitHub.
def test_folder_and_file_paths_that_end_with_bad_name():
    fi_path, fo_path = get_abs_cfg_paths(FILES_CFG_PATH, FOLDER_CFG_PATH)

    assert (
        "src/python/hooks/tests/.ignoredfolder"
        in fnc.load_config(fo_path)["ignore_folders"]
    )

    bad_names = {
        Path("src/python/hooks/tests/.badfolder"),
    }

    file_paths = [
        Path("src/python/hooks/tests/.ignoredfolder"),
        Path("src/python/hooks/tests/.badfolder"),
        Path("src/python/hooks/tests/.testfile"),
    ]

    assert bad_names == fnc.check_folders(file_paths, fo_path)


def test_bad_folder_name():
    fi_path, fo_path = get_abs_cfg_paths(FILES_CFG_PATH, FOLDER_CFG_PATH)

    bad_names = {
        Path(".folder"),
        Path(".folder/.folder"),
        Path(".folder/.folder/bad_name"),
        Path("test/.folder/.folder/bad_name"),
        Path("test/.folder/.folder"),
        Path("test/.folder"),
    }

    file_paths = [
        abs_path(".folder/.folder/bad_name/good-name/file.ts"),
        abs_path("test/.folder/.folder/bad_name/good-name/file.ts"),
    ]

    assert bad_names == fnc.check_folders(file_paths, fo_path)


def test_bad_file_name():
    fi_path, fo_path = get_abs_cfg_paths(FILES_CFG_PATH, FOLDER_CFG_PATH)

    file_cfg = fnc.load_config(fi_path)

    assert "pyproject.toml" in file_cfg["ignore_files"]

    bad_names = {
        abs_path("src/some/path/some_toml_file.toml"),
        abs_path("some-file.py"),
        abs_path("src/ts/some_file.ts"),
        abs_path("some_filetype.random"),
        abs_path("smart-contract.move"),
        abs_path("rust-file.rs"),
        abs_path("RustFile.rs"),
        abs_path("my_bad/__rust-file__.rs"),
    }

    file_paths = [
        abs_str_path("src/some/path/some_toml_file.toml"),
        abs_str_path("src/some/path/MyTomlFile.toml"),
        abs_str_path("some-file.py"),
        abs_str_path("some_file.py"),
        abs_str_path("__init__.py"),
        abs_str_path("src/ts/some_file.ts"),
        abs_str_path("src/ts/some-file.ts"),
        abs_str_path("some_filetype.random"),
        abs_str_path("some-filetype.random"),
        abs_str_path("smart_contract.move"),
        abs_str_path("smart-contract.move"),
        abs_str_path("rust_file.rs"),
        abs_str_path("rust-file.rs"),
        abs_str_path("RustFile.rs"),
        abs_str_path("my_bad/__rust-file__.rs"),
        abs_str_path("my_good/__rust_file__.rs"),
        abs_str_path("src/python/hooks/some_file_AF_@#4j >XC.md"),
    ]

    assert bad_names == fnc.check_files(file_paths, fi_path)
