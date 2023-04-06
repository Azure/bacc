import os.path
import sys

from knack import CLI
from .commands import CommandsLoader

name = "sb"
message = r"""
Welcome to CLI for sbatch: an  Azure Batch accelerator
"""
cli = CLI(
    cli_name=name,
    config_dir=os.path.expanduser(os.path.join("~", ".{}".format(name))),
    config_env_var_prefix=name.upper().replace("-", "_"),
    commands_loader_cls=CommandsLoader,
)
#   welcome_message=message)

sys.exit(cli.invoke(sys.argv[1:]))
