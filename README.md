# usdt-vy

![Cover](assets/cover.png)

An educational rebuild of the USDT (Tether USD) Ethereum contract in [Vyper](https://vyperlang.org/), built from reusable modules. Read the full walkthrough in [ARTICLE.md](ARTICLE.md).

## Structure

```
modules/
├── erc20.vy       # balances, allowances, mint/burn
├── ownable.vy     # single-owner access control
├── pausable.vy    # emergency stop
└── blacklist.vy   # freeze addresses, destroy frozen funds
contracts/
└── usdt.vy        # the token: issue, redeem, pause, blacklist
tests/
└── test_usdt.py
```

## Usage

Requires [uv](https://docs.astral.sh/uv/).

```
uv sync
uv run pytest
```

## Disclaimer

For learning purposes only. Not audited, and not affiliated with Tether.
