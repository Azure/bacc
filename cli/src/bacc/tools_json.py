from knack.commands import CommandGroup
from knack.arguments import ArgumentsContext
from knack.help_files import helps
from knack.log import get_logger
import pyjson5
import json

import os.path

log = get_logger(__name__)

helps[
    "json"
] = r"""
    type: group
    short-summary: Miscellaneous json tools
    long-summary: |
        This command group contains miscellaneous json tools. These are primarily intended for
        use for testing and debugging.
"""

helps[
    "json concat"
] = r"""
    type: command
    short-summary: Concatenate json files
    long-summary: |
        This command concatenates json files. The output is a single json file containing
        all of the input json files. If input files include comments i.e. as JSONC files,
        the comments are stripped in the output.
"""

helps[
    "json strip"
] = r"""
    type: command
    short-summary: Strip json files to remove comments
    long-summary: |
        This command strips json files to remove comments. The output is a single json file
        containing all of the input json files.
"""


def populate_commands(loader):
    with CommandGroup(loader, "json", "bacc.tools_json#{}") as g:
        g.command("concat", "concat")
        g.command("strip", "strip")


def populate_arguments(loader):
    with ArgumentsContext(loader, "json") as c:
        c.argument(
            "input_files",
            options_list=["--input-files", "-i"],
            help="The input files to concatenate. Multiple files can be specified separated by spaces.",
            nargs="+",
        )
        c.argument(
            "input_file",
            options_list=["--input-file", "-i"],
            help="The input file to strip.",
        )
        c.argument(
            "use_union",
            options_list=["--use-union", "-u"],
            help="Use union instead of merge.",
            action="store_true",
        )


def concat(input_files, use_union=False):
    """Concatenate json files."""
    log.info("Concatenating json files...%s", str(input_files))
    inputs = []
    for input_file in input_files:
        log.info("  %s", input_file)
        with open(input_file, "r") as fp:
            inputs.append(pyjson5.loads(fp.read(), allow_duplicate_keys=False))
    if use_union:
        output = {}
        for input in inputs:
            output.update(input)
    else:
        output = []
        for input in inputs:
            output.extend(input)
    return output

def strip(input_file):
    """Strip json files to remove comments."""
    log.info("Stripping json file...")
    with open(input_file, "r") as fp:
        input = fp.read()
    output = pyjson5.loads(input, allow_duplicate_keys=False)
    return output
