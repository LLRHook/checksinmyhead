import Foundation
import Network

enum WakeOnLanError: LocalizedError, Equatable, Sendable {
    case invalidMACAddress
    case invalidPort
    case sendTimeout
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidMACAddress:
            "Enter a 12-digit MAC address, with or without '-' or ':' separators."
        case .invalidPort:
            "Enter a UDP port from 1 to 65535."
        case .sendTimeout:
            "Timed out while sending the wake packet."
        case .sendFailed(let message):
            "Wake packet failed: \(message)"
        }
    }
}

struct WakeOnLanClient: Sendable {
    private let timeoutSeconds: TimeInterval

    init(timeoutSeconds: TimeInterval = 5) {
        self.timeoutSeconds = timeoutSeconds
    }

    func sendMagicPacket(macAddress: String, host: String, port: UInt16) async throws {
        let packet = try Self.magicPacket(macAddress: macAddress)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw WakeOnLanError.invalidPort
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .udp
        )
        let state = WakePacketSendState(connection: connection)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                state.start(packet: packet, timeoutSeconds: timeoutSeconds, continuation: continuation)
            }
        } onCancel: {
            state.cancel()
        }
    }

    static func magicPacket(macAddress: String) throws -> Data {
        let macBytes = try parsedMACBytes(from: macAddress)
        var packet = Data(repeating: 0xFF, count: 6)

        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        return packet
    }

    static func parsedMACBytes(from macAddress: String) throws -> [UInt8] {
        let normalized = macAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")

        guard normalized.count == 12, normalized.allSatisfy(\.isHexDigit) else {
            throw WakeOnLanError.invalidMACAddress
        }

        var bytes: [UInt8] = []
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let nextIndex = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<nextIndex], radix: 16) else {
                throw WakeOnLanError.invalidMACAddress
            }
            bytes.append(byte)
            index = nextIndex
        }

        guard bytes.count == 6 else {
            throw WakeOnLanError.invalidMACAddress
        }

        return bytes
    }
}

private final class WakePacketSendState: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "VictorWake.WakeOnLanClient")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var didSend = false

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start(
        packet: Data,
        timeoutSeconds: TimeInterval,
        continuation: CheckedContinuation<Void, Error>
    ) {
        self.continuation = continuation

        connection.stateUpdateHandler = { [self] state in
            switch state {
            case .ready:
                self.send(packet)
            case .failed(let error):
                self.finish(throwing: WakeOnLanError.sendFailed(error.localizedDescription))
            case .cancelled:
                self.finish(throwing: CancellationError())
            default:
                break
            }
        }

        connection.start(queue: queue)

        queue.asyncAfter(deadline: .now() + timeoutSeconds) { [self] in
            self.finish(throwing: WakeOnLanError.sendTimeout)
        }
    }

    func cancel() {
        finish(throwing: CancellationError())
    }

    private func send(_ packet: Data) {
        lock.lock()
        let shouldSend = !didSend
        didSend = true
        lock.unlock()

        guard shouldSend else { return }

        connection.send(content: packet, completion: .contentProcessed { [self] error in
            if let error {
                self.finish(throwing: WakeOnLanError.sendFailed(error.localizedDescription))
            } else {
                self.finish()
            }
        })
    }

    private func finish() {
        let continuation = takeContinuation()
        guard let continuation else { return }

        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume()
    }

    private func finish(throwing error: Error) {
        let continuation = takeContinuation()
        guard let continuation else { return }

        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }

        let current = continuation
        continuation = nil
        return current
    }
}
