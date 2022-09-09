import Foundation

final class TalkPageCellCommentViewModel {

    let commentId: String
    let text: String
    let author: String
    let authorTalkPageURL: String
    let timestamp: Date?
    let replyDepth: Int
    
    init?(commentId: String, text: String?, author: String?, authorTalkPageURL: String, timestamp: Date?, replyDepth: Int?) {
        
        guard let text = text,
              let author = author,
              let replyDepth = replyDepth else {
            return nil
        }
        
        self.commentId = commentId
        self.text = text
        self.author = author
        self.authorTalkPageURL = authorTalkPageURL
        self.timestamp = timestamp
        self.replyDepth = replyDepth
    }

}
