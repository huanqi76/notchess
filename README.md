# Notchess

Chess puzzles in your MacBook's notch.

Send `/start` and a pulsing dot appears beside the notch after five seconds. Hover over the notch to open a puzzle, solve it or skip it, and move away to collapse it. Send `/stop` to dismiss it.

```sh
curl localhost:7777/start
curl localhost:7777/stop
```

Any tool that can make an HTTP request can drive it, such as a shell hook that fires while a long job runs. The server listens on loopback only.

## Build

Open `Notchess.xcodeproj` in Xcode and run. It lives in the menu bar (hourglass icon) and needs a Mac with a notch.

## Credits

- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) by MrKai77
- Puzzles: a 2,000-puzzle sample of the [Lichess puzzle database](https://database.lichess.org/#puzzles) (CC0)
- Pieces: cburnett set by Colin M.L. Burnett
