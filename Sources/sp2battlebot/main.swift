import Foundation
import Telegrammer

// shell: export SP2BATTLE_BOT_TOKEN="Your bot token"
guard let token = Enviroment.get("SP2BATTLE_BOT_TOKEN") else {
    print("SP2BATTLE_BOT_TOKEN variable wasn't found in enviroment variables")
    exit(1)
}

let settings = Bot.Settings(token: token, debugMode: true)
let bot = try! Bot(settings: settings)

// Run bot befor get bot info
let botUser = try! bot.getMe().wait()

TGMessageManager.shared.bot = bot
TGMessageManager.shared.botUser = botUser

do {
    try DataStore.shared.createTables()
} catch {
    print("SQLite createTables error: \(error)")
    exit(1)
}

let controller = BotController()

let startHandler = CommandHandler(commands: ["/start", "/start@\(botUser.username!)"],
                                  callback: controller.start)

let stopHandler = CommandHandler(commands: ["/stop", "/stop@\(botUser.username!)"],
                                 callback: controller.stop)

let lastWithIndexHandler = RegexpHandler(pattern: "^/last ",
                                         callback: controller.lastWithIndex)

let lastHandler = CommandHandler(commands: ["/last", "/last@\(botUser.username!)"],
                                 callback: controller.last)

let last50Handler = CommandHandler(commands: ["/last50", "/last50@\(botUser.username!)"],
                                 callback: controller.last50)

let setIKSMSessionHandler = RegexpHandler(pattern: "^/setiksm",
                                          callback: controller.setIKSMSession)

let dispatcher = Dispatcher(bot: bot)
dispatcher.add(handler: stopHandler)
dispatcher.add(handler: startHandler)
dispatcher.add(handler: last50Handler)
dispatcher.add(handler: lastWithIndexHandler)
dispatcher.add(handler: lastHandler)
dispatcher.add(handler: setIKSMSessionHandler)

_ = try Updater(bot: bot, dispatcher: dispatcher).startLongpolling().wait()
