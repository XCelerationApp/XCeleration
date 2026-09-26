//
//  MPCManager.swift
//  multipeer_connections
//
//  Created by NamIT on 9/3/20.
//
//  XCeleration changes, not in the upstream plugin:
//  - Every change to `devices` happens on the main queue. MultipeerConnectivity
//    calls its delegates on its own queues, and the list was read and written
//    from several at once.
//  - `setup` starts clean. It used to leave the last session's advertiser,
//    browser and phones in place, so a second transfer in one run of the app
//    saw a phone from the first still "connected" with no session behind it.
//  - A phone that is found again, or stops advertising, keeps a connection
//    it already has. Both used to replace or drop it mid-transfer.
//  - Advertising and browsing start again when the app comes back to the
//    foreground, since iOS stops them in the background.
//

import Foundation
import MultipeerConnectivity

class MPCManager: NSObject {

    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?

    struct Notifications {
        static let deviceDidChangeState = Notification.Name("deviceDidChangeState")
    }

    static let instance = MPCManager()

    var localPeerID: MCPeerID!
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    /// Whether this phone was asked to advertise or browse, so both can start
    /// again after the app returns from the background.
    private var isAdvertising = false
    private var isBrowsing = false

    var devices: [Device] = [] {
        didSet {
            deviceDidChange?()
        }
    }

    var deviceDidChange: (() -> Void)?

    deinit {
        removeObservers()
    }

    private func removeObservers() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    /// Runs [work] on the main queue: now if already there, else next.
    static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func setup(serviceType: String, deviceName: String) {
        // Start clean: stop the last session's advertiser and browser and
        // drop its phones, so none of them is mistaken for this session's.
        tearDown()

        if let data = UserDefaults.standard.data(forKey: deviceName), let id = NSKeyedUnarchiver.unarchiveObject(with: data) as? MCPeerID {
            self.localPeerID = id
        } else {
            let peerID = MCPeerID(displayName: deviceName)
            let data = NSKeyedArchiver.archivedData(withRootObject: peerID)
            UserDefaults.standard.set(data, forKey: deviceName)
            self.localPeerID = peerID
        }

        let advertiser = MCNearbyServiceAdvertiser(peer: localPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        browser.delegate = self
        self.browser = browser

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in self?.enteredBackground() }
        )
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in self?.enteredForeground() }
        )
    }

    /// Stops advertising and browsing and disconnects every phone.
    private func tearDown() {
        removeObservers()
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        isAdvertising = false
        isBrowsing = false
        for device in devices {
            device.disconnect()
        }
        devices = []
    }

    func startAdvertisingPeer() {
        isAdvertising = true
        advertiser?.startAdvertisingPeer()
    }

    func startBrowsingForPeers() {
        isBrowsing = true
        browser?.startBrowsingForPeers()
    }

    func stopAdvertisingPeer() {
        isAdvertising = false
        advertiser?.stopAdvertisingPeer()
    }

    func stopBrowsingForPeers() {
        isBrowsing = false
        for device in devices {
            device.disconnect()
        }
        browser?.stopBrowsingForPeers()
    }

    func invitePeer(deviceID: String) {
        guard let browser = browser,
              let device = findDevice(for: deviceID),
              device.state == .notConnected else { return }
        device.invite(with: browser)
    }

    func disconnectPeer(deviceID: String) {
        findDevice(for: deviceID)?.disconnect()
    }

    @discardableResult
    func addNewDevice(for id: MCPeerID) -> Device {
        devices = devices.filter { $0.peerID.displayName != id.displayName }
        let device = Device(peerID: id)
        devices.append(device)
        return device
    }

    func findDevice(for deviceId: String) -> Device? {
        return devices.first { $0.peerID.displayName == deviceId }
    }

    func findDevice(for id: MCPeerID) -> Device? {
        return devices.first { $0.peerID == id }
    }

    private func enteredBackground() {
        // iOS ends the sessions in the background anyway; say so now, so the
        // app looks for the other phone again when it comes back.
        for device in devices {
            device.disconnect()
        }
        devices = []
    }

    private func enteredForeground() {
        // iOS stops advertising and browsing in the background. Start them
        // again if this phone was doing either.
        if isAdvertising {
            advertiser?.stopAdvertisingPeer()
            advertiser?.startAdvertisingPeer()
        }
        if isBrowsing {
            browser?.stopBrowsingForPeers()
            browser?.startBrowsingForPeers()
        }
    }
}

extension MPCManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        MPCManager.onMain {
            guard advertiser === self.advertiser else {
                invitationHandler(false, nil)
                return
            }
            // A phone inviting again has lost the last session on its side:
            // end this side of it before starting a new one.
            self.findDevice(for: peerID.displayName)?.disconnect()
            let device = self.addNewDevice(for: peerID)
            device.createSession()
            invitationHandler(true, device.session)
        }
    }
}

extension MPCManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        MPCManager.onMain {
            guard browser === self.browser else { return }
            // Keep a phone already known: replacing it dropped a connection
            // in progress. A new peer under a known name (the other phone
            // reinstalled the app) replaces one that is not connected.
            if let existing = self.findDevice(for: peerID.displayName) {
                if existing.peerID == peerID || existing.state != .notConnected {
                    return
                }
                existing.disconnect()
            }
            self.addNewDevice(for: peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        MPCManager.onMain {
            guard browser === self.browser,
                  let device = self.findDevice(for: peerID) else { return }
            // A phone that stops advertising keeps any session it has with
            // this one: only one never connected is forgotten.
            guard device.state == .notConnected else { return }
            device.disconnect()
            self.devices = self.devices.filter { $0 !== device }
        }
    }
}
