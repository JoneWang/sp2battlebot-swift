//
// Created by Jone Wang on 24/9/2019.
//

import Foundation
import Telegrammer

struct TGMessageManager {
    static var shared = TGMessageManager()

    var bot: Bot!
    var botUser: TelegramUser!

    func send(context: DataContext, message: TGMessage, parseMode: ParseMode? = nil) -> Future<Message> {
        let message = TGMessage.selector(context: context, message: message)
        print(message)
        let params = Bot.SendMessageParams(chatId: .chat(context.chat.id),
                                           text: message,
                                           parseMode: parseMode)
        return try! bot.sendMessage(params: params)
    }

    func delete(context: DataContext, messageId: Int) -> Future<Bool> {
        let params = Bot.DeleteMessageParams(chatId: .chat(context.chat.id),
                                             messageId: messageId)
        return try! bot.deleteMessage(params: params)
    }
}