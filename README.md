# my-zshrc

This is my `.zshrc`, duh.

**This has been superseded by [kugland/zk](http://github.com/kugland/zk), which is basically a modular
and documented rewriting of this config.**

## Using with PuTTY

Either set `TERM` to `putty` or `putty-*`, or set `PUTTY` to `1`, and
`zshrc` will detect that it should use PuTTY’s key codes.

## Overriding prompt type

Set the env var `_myzshrc_prompt` to `minimal`, `simple` or `fancy`, and the prompt type will be overriden.
