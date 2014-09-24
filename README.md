# hype_machine

Command line tool for downloading songs from HypeMachine.

It is **highly** recommended to [use Tor](https://www.torproject.org/download/download-easy.html.en) and [run the command](#Usage) with the `--tor` / `-r` option so you don't get blocked (initial IP ban is 24 hours).

It is _also_ recommended to use be somewhat considerate and use the `--wait` / `-w` option with a sensible amount (say, 15 seconds: `-w 15`) if you are downloading more than a few tracks.

## Usage

```
hypem [options?] path directory?

example: Download all 50 songs from the Popular list, using Tor and waiting 15 seconds between tracks.
    hypem -r -w 15 -f 3 popular

path: Required.
    HypeMachine user, blog, section, artist, etc.
    Paths with spaces must be quoted.
    (e.g., anthony, blog/earmilk/11067, popular, "artist/Wiz Khalifa")

directory: Optional.
    Absolute or relative path to a new or existing directory to download to.
    Paths with spaces must be quoted.
    (e.g. /usr/music, ../music/hype_machine, "C:\Users\Guest\My Documents\Music")
    If not provided, a directory will be chosen based on the path given and relative to the current directory.

options: Optional.
    -h, --help                       Display this help screen
    -v, --version                    Display the script version
    -s, --start START                Download tracks starting from page #START
    -f, --finish FINISH              Download tracks ending on page #FINISH
    -w, --wait WAIT                  Wait #WAIT seconds before downloading each track
    -r, --tor                        Use Tor as a proxy (--host=127.0.0.1 --port=9151)
    -x, --proxy PROXY                Route through proxy host PROXY
    -p, --port PORT                  Route through proxy port #PORT
    -o, --overwrite                  Turn on overwrite mode to overwrite existing files
    -q, --quiet                      Turn on quiet mode to hide console output
    -t, --strict                     Turn on strict mode to fail on track errors
    -d, --demo                       Turn on demo mode to skip downloading

```

## Copyright

Copyright (c) 2014 Jordan Sexton. See LICENSE.txt for further details.
