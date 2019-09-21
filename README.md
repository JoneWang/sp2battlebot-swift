# sp2battlebot

A bot for telegram. Get your own battle info in telegram.

## Startup

``` bash
export SP2BATTLE_BOT_TOKEN="Your bot token"
export SP2BATTLE_PRIVATE_SESSION="Your nintedio switch online cookie"
```

```bash
./sp2battlebot
```

## Command

/last - Get last battle info.

/last[0~49] - Get last battle with index.

/start - Startup service of push.

/stop - Stop service.

## Build

```bash
swift build
```

or use Xcode

```bash
swift package generate-xcodeproj
```

