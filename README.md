# Pixamo
Generates sprites from pixel art skeleton
Made as a tool for my game for [OLC CodeJam 2024](https://itch.io/jam/olc-codejam-2024), can be used as a submission by itself :)

# Usage
Clone this repository, run `pip install .` to install it.
Run `pixamo pose.png skinmap.png -s skin.png -o image.png` to map skin.png to pose.png using skinmap.png outputing image.png.
Example files can be found [in example directory](https://github.com/InfiniteCoder01/pixamo/tree/master/example)
If you are using nix, it is also available as a flake: `nix run github:InfiniteCoder01/pixamo -- pose.png skinmap.png -s skin.png -o image.png`
