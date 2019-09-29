//
// Created by Jone Wang on 24/9/2019.
//

import Foundation
import Telegrammer

struct TGMessageManager {
    static var shared = TGMessageManager()

    var bot: Bot!
    var botUser: TelegramUser!

    func send(context: DataContext, message: TGMessage, chatId: Int64? = nil, parseMode: ParseMode? = nil) -> Future<Message> {
        let message = TGMessage.selector(context: context, message: message)
        print(message)
        let cId = chatId == nil ? context.chat.id : chatId!
        let params = Bot.SendMessageParams(chatId: .chat(cId),
                                           text: message,
                                           parseMode: parseMode)
        return try! bot.sendMessage(params: params)
    }

    func delete(context: DataContext, messageId: Int, chatId: Int64? = nil) -> Future<Bool> {
        let cId = chatId == nil ? context.chat.id : chatId!
        let params = Bot.DeleteMessageParams(chatId: .chat(cId),
                                             messageId: messageId)
        return try! bot.deleteMessage(params: params)
    }
}
