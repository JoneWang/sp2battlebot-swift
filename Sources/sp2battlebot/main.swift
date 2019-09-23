import Foundation
import Telegrammer

// shell: export SP2BATTLE_BOT_TOKEN="Your bot token"
guard let token = Enviroment.get("SP2BATTLE_BOT_TOKEN") else {
    print("SP2BATTLE_BOT_TOKEN variable wasn't found in enviroment variables")
    exit(1)
}

// shell: export SP2_PRIVATE_SESSION="Your nintendio switch online session"
guard var onlineSession = Enviroment.get("ONLINE_USER_SESSION") else {
    print("ONLINE_USER_SESSION variable wasn't found in enviroment variables")
    exit(1)
}

var settings = Bot.Settings(token: token, debugMode: true)

let bot = try! Bot(settings: settings)

// Run bot befor get bot info
let botUser = try! bot.getMe().wait()

let controller = BotController(bot: bot, botUser: botUser, onlineSession: onlineSession)

let dispatcher = Dispatcher(bot: bot)

let startHandler = CommandHandler(commands: ["/start", "/start@\(botUser.username!)"],
                                         callback: controller.start)
dispatcher.add(handler: startHandler)

let lastWithIndexHandler = RegexpHandler(pattern: "^/last ",
                                         callback: controller.lastWithIndex)
dispatcher.add(handler: lastWithIndexHandler)

let lastHandler = CommandHandler(commands: ["/last", "/last@\(botUser.username!)"],
                                         callback: controller.last)
dispatcher.add(handler: lastHandler)

_ = try Updater(bot: bot, dispatcher: dispatcher).startLongpolling().wait()
