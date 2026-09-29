# Device binding regression tests

Run from the repository root with Python 3 and the official [Luau CLI](https://github.com/luau-lang/luau/releases):

```sh
python tests/run.py --luau /path/to/luau
```

The runner inserts the actual library and combo module into a fresh mocked Roblox
runtime for each test. It changes only the two module `require` expressions, so
binding setup, input dispatch, combo queries, and the public APIs run as written.
Signals, enum values, the last input device, and delayed tasks are mocked. These
tests do not verify Roblox Studio integration, real hardware, or timer expiry.

To reproduce the failure with the original implementation:

```sh
python tests/run.py --luau /path/to/luau --source-ref origin/main
```

This should fail the first test, which checks that an explicit PC rebind is
respected while gamepad input is active.
