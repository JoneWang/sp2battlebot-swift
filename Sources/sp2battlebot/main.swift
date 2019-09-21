import Foundation
import TelegramBotSDK

// shell: export SP2BATTLE_BOT_TOKEN="Your bot token"
let token = readToken(from: "SP2BATTLE_BOT_TOKEN")

// shell: export SP2_PRIVATE_SESSION="Your nintendio switch online session"
guard let sp2Session: String = readConfigurationValue("SP2BATTLE_PRIVATE_SESSION") else {
    print("\n" +
        "-----\n" +
        "ERROR\n" +
        "-----\n" +
        "Please create either:\n" +
        "  - an environment variable named SP2BATTLE_PRIVATE_SESSION\n" +
        "  - a file named SP2BATTLE_PRIVATE_SESSION\n" +
        "containing your switch online session.\n\n")
    exit(1)
}

let bot = TelegramBot(token: token)
let controller = BotController(bot: bot, sp2Session: sp2Session)

let router = Router(bot: bot)
router["start"] = controller.start
router["last"] = controller.last
router["stop"] = controller.stop
// 10场战斗 last 命令
for i in 0..<10 {
    router["last\(i)"] = controller.lastFuncs[i]
}

while let update = bot.nextUpdateSync() {
    try router.process(update: update)
}

fatalError("Server stopped due to error: \(String(describing: bot.lastError))")
