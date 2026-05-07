import UIKit
import Social
import KhanIPC

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        let title = String(contentText.prefix(64))
        let body = contentText
        let payload = IPCNotifyPayload(
            title: title,
            body: body,
            displayMode: .banner,
            source: .share,
            sourceAppId: "share-extension-ios"
        )
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        try? IPCDirectory.ensureDirectories()
        try? IPCWriter.enqueue(request)
        IPCWriter.kick()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func configurationItems() -> [Any]! { [] }
}
