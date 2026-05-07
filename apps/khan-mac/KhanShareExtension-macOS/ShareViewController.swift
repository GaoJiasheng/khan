import Cocoa
import KhanIPC

final class ShareViewController: NSViewController {
    @IBOutlet weak var titleField: NSTextField!
    @IBOutlet weak var bodyField: NSTextView!

    override var nibName: NSNib.Name? { "ShareViewController" }

    override func loadView() {
        // Programmatic UI fallback — ships without xib for v1.
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))
        let titleField = NSTextField(frame: NSRect(x: 16, y: 154, width: 328, height: 24))
        titleField.placeholderString = "Title"
        let body = NSTextField(frame: NSRect(x: 16, y: 60, width: 328, height: 80))
        body.placeholderString = "Body"
        let saveAsNote = NSButton(title: "Save as Note", target: self, action: #selector(saveNote(_:)))
        saveAsNote.frame = NSRect(x: 16, y: 16, width: 140, height: 30)
        let sendInbox = NSButton(title: "Send to Inbox", target: self, action: #selector(sendInbox(_:)))
        sendInbox.frame = NSRect(x: 200, y: 16, width: 140, height: 30)

        view.addSubview(titleField)
        view.addSubview(body)
        view.addSubview(saveAsNote)
        view.addSubview(sendInbox)
        self.view = view
        self.titleField = titleField
    }

    @objc func saveNote(_ sender: Any) {
        let payload = IPCNoteAddPayload(title: titleField.stringValue, body: bodyText())
        let request = IPCRequest(kind: .noteAdd, payload: .noteAdd(payload))
        try? IPCDirectory.ensureDirectories()
        try? IPCWriter.enqueue(request)
        IPCWriter.kick()
        complete()
    }

    @objc func sendInbox(_ sender: Any) {
        let payload = IPCNotifyPayload(
            title: titleField.stringValue,
            body: bodyText(),
            displayMode: .banner,
            source: .share,
            sourceAppId: "share-extension"
        )
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        try? IPCDirectory.ensureDirectories()
        try? IPCWriter.enqueue(request)
        IPCWriter.kick()
        complete()
    }

    private func bodyText() -> String {
        // Best-effort extraction of attachments from the share extension item.
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else { return "" }
        let pieces = (item.attachments ?? []).compactMap { provider -> String? in
            if provider.hasItemConformingToTypeIdentifier("public.url"),
               let item = try? provider.loadItem(forTypeIdentifier: "public.url"),
               let url = item as? URL { return url.absoluteString }
            if provider.hasItemConformingToTypeIdentifier("public.text"),
               let item = try? provider.loadItem(forTypeIdentifier: "public.text"),
               let text = item as? String { return text }
            return nil
        }
        return pieces.joined(separator: "\n")
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
