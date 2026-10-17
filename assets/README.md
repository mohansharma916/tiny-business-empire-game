# assets — owner: Antigravity

Suggested layout:

```
assets/
├── placeholder/     temporary art (replace before soft launch)
├── atlases/         one sprite atlas per location
├── businesses/      business sprites, 4 visual levels each (1, 25, 50, 100)
├── customers/
├── ui/              icons, panels, buttons
├── fonts/           must support Latin and Devanagari (Hindi)
└── audio/
```

Keep the initial download under 80 MB. Use PNG sources; Godot compresses them to ETC2/ASTC on import.
