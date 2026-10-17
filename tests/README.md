# tests — owner: Claude Code

Unit tests use **GUT** (Godot Unit Test). Install it from the AssetLib into `addons/gut/`.

Run all tests:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Name files `test_<thing>.gd` (for example `test_big_number.gd`, `test_economy_service.gd`,
`test_save_system.gd`, `test_offline_earnings.gd`). Run tests before every commit.
