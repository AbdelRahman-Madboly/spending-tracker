# Launcher icon artwork

`source_wallet_egp.jpeg` is the original artwork. The launcher layers
(`app_icon.png`, `app_icon_foreground.png`, `app_icon_monochrome.png`) are cut
from it: background removed, art centred on `#71C5EC` and sized to fit the
Android adaptive-icon mask. Regenerate the Android resources with
`fvm dart run flutter_launcher_icons`.

## Brief

A high-resolution pixel art illustration, centrally focused, within a solid
light-blue square background with rounded corners, like an app icon. The main
subject is an open, dark-brown pixelated leather bifold wallet, shown from a
slightly high isometric perspective. The wallet is detailed with pixelated
light-brown stitching around its edges. The mouth of the wallet is wide open,
revealing multiple internal card slots and compartments. A single, stylized
pixelated metal snap closure is visible on the inner flap. On the front-most
face of the wallet, large, bold, pixelated yellow capital letters clearly
display the text: "EGP".

Erupting in a dynamic, cascading stream upwards and to the left from the open
mouth of the wallet is a large quantity of golden, pixelated coins. At least
ten coins are visible, tumbling in mid-air, with others partially obscured.
Each golden coin features a simplified yet recognizable pixel art emblem on its
face: a stylized, simplified pharaonic bust (or pharaoh's profile head). Small
pixelated sparkle effects and directional motion trails are interspersed among
the flying coins. The overall style is clean, retro 16-bit pixel art, with
simple, flat-panel shading and a clear, focused composition.

## Tips for a new version

- Keep the background one flat colour with no rounded corners or frame; the
  phone applies its own mask shape.
- Keep the subject inside the middle 60% of the square so no mask clips it.
- Fewer, larger coins read better at 48dp than many small ones.
