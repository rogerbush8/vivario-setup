# install-sequence

Install ordering lives here, and nowhere else.

`verify` is order-free -- checks are independent. `install` is not: uv has to be
present before anything uv installs. But a command must never be *named* for its
position, because the same command is also something a person runs directly.
`vivo-setup verify prerequisites` is a real command with a real name;
`01_prerequisites` is not.

So the two concerns are separated. `commands/` holds normally-named commands.
This directory holds the order they run in, as numerically prefixed entries that
refer to those commands:

    10-uv
    20-python
    30-cmux

Adding a step is a new numbered entry here and no edit to anything above it, so
sequencing keeps the same self-discovery property the command tree has. Renaming
a command does not renumber anything, and renumbering does not rename a command.

Empty for now -- the install commands do not exist yet.
