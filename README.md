# sp2battlebot

A bot for telegram. Get your own battle info in telegram.

## Startup

``` bash
export SP2BATTLE_BOT_TOKEN="Your bot token"
```

```bash
./sp2battlebot
```

## Command

/setiksm - Set iksm_session.

/last - last50 - Show overview for last 50 battle.

/last - Get last battle info.

/last [0~49] - Get last battle with index.

/start - Startup service of push.

/stop - Stop service.

## Require

* swift 5.1

## Build

```bash
swift build
```

or use Xcode

```bash
swift package generate-xcodeproj
```

