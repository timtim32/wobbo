# Contributing to Wobbo

Thanks for wanting to help. Bug reports and ideas are welcome as
[issues](https://github.com/timtim32/wobbo/issues). Wobbo is a hobby project,
so answers can take a while.

## Pull requests

- For anything bigger than a small fix, open an issue first, so we can agree on
  the approach before you spend time on it.
- Keep a pull request to one change, and describe what it changes and how you
  checked it.
- Run the tests that match your change (see
  [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)): `bun test` in `bridge/`, and the
  headless Godot tests for the app.
- Bigger changes are planned as an OpenSpec change in `openspec/changes/`;
  code comments refer to their design decisions as `(<change> Dn)`.

## Licensing of contributions

By opening a pull request you agree that:

1. your contribution is your own work, or you have the right to submit it;
2. code you contribute is licensed under the MIT License of this repository;
3. artwork you contribute falls under the same terms as the rest of the Wobbo
   artwork (see [ARTWORK.md](ARTWORK.md)); and
4. the maintainer may also license your contribution under other terms, so the
   project can change its license later.
