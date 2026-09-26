import Foundation
import MultipeerConnectivity
import SwiftyJSON

enum DeviceSendError: Error {
    /// There is no session with this phone, or it is not connected, so the
    /// message would go nowhere.
    case notConnected
}

class Device: NSObject {
    let peerID: MCPeerID
    var session: MCSession?
    var state = MCSessionState.notConnected
    var lastMessageReceived: Message?

    static let messageReceivedNotification = Notification.Name("DeviceDidReceiveMessage")

    init(peerID: MCPeerID) {
        self.peerID = peerID
        super.init()
    }

    func createSession() {
        if self.session != nil { return }
        self.session = MCSession(peer: MPCManager.instance.localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.session?.delegate = self
    }

    /// Ends the session with this phone. The state says so at once: the
    /// session's own report may never come once it is let go, which left the
    /// phone looking connected with nothing behind it.
    func disconnect() {
        let old = self.session
        self.session = nil
        old?.delegate = nil
        old?.disconnect()
        self.state = .notConnected
        NotificationCenter.default.post(name: MPCManager.Notifications.deviceDidChangeState, object: self)
    }

    func invite(with browser: MCNearbyServiceBrowser) {
        if (self.state == MCSessionState.notConnected) {
            self.createSession()
            if let session = session {
                browser.invitePeer(self.peerID, to: session, withContext: nil, timeout: 10)
            }
        }
    }
}

extension Device: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        MPCManager.onMain {
            // A session this phone has already let go may still report; it
            // must not change the state of the one that replaced it.
            guard session === self.session, peerID == self.peerID else { return }
            self.state = state
            NotificationCenter.default.post(name: MPCManager.Notifications.deviceDidChangeState, object: nil)
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NotificationCenter.default.post(name: Device.messageReceivedNotification, object: nil, userInfo: ["from": peerID, "data": data])
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }

}
