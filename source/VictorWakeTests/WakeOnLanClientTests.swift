import Foundation
import Darwin
import Testing
@testable import VictorWake

struct WakeOnLanClientTests {
    @Test func parsesSupportedMACAddressFormats() throws {
        let expected: [UInt8] = [0xD8, 0x43, 0xAE, 0x2C, 0x9D, 0xB2]

        #expect(try WakeOnLanClient.parsedMACBytes(from: "D8-43-AE-2C-9D-B2") == expected)
        #expect(try WakeOnLanClient.parsedMACBytes(from: "D8:43:AE:2C:9D:B2") == expected)
        #expect(try WakeOnLanClient.parsedMACBytes(from: "D843AE2C9DB2") == expected)
    }

    @Test func magicPacketHasExpectedWakeOnLanLayout() throws {
        let packet = try WakeOnLanClient.magicPacket(macAddress: "D8-43-AE-2C-9D-B2")
        let macBytes: [UInt8] = [0xD8, 0x43, 0xAE, 0x2C, 0x9D, 0xB2]

        #expect(packet.count == 102)
        #expect(Array(packet.prefix(6)) == Array(repeating: 0xFF, count: 6))

        for repeatIndex in 0..<16 {
            let start = 6 + (repeatIndex * macBytes.count)
            let end = start + macBytes.count
            #expect(Array(packet[start..<end]) == macBytes)
        }
    }

    @Test func rejectsInvalidMACAddress() {
        #expect(throws: WakeOnLanError.invalidMACAddress) {
            _ = try WakeOnLanClient.magicPacket(macAddress: "D8-43-AE-2C-9D")
        }
    }

    @Test func sendsMagicPacketOverUDP() async throws {
        let socketFileDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        try #require(socketFileDescriptor >= 0)
        defer { close(socketFileDescriptor) }

        var receiveTimeout = timeval(tv_sec: 2, tv_usec: 0)
        let timeoutResult = setsockopt(
            socketFileDescriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &receiveTimeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
        try #require(timeoutResult == 0)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(
                    socketFileDescriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        try #require(bindResult == 0)

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(socketFileDescriptor, socketAddress, &boundAddressLength)
            }
        }
        try #require(nameResult == 0)

        let boundPort = UInt16(bigEndian: boundAddress.sin_port)
        try #require(boundPort > 0)

        async let sendResult: Void = WakeOnLanClient(timeoutSeconds: 2).sendMagicPacket(
            macAddress: "D8-43-AE-2C-9D-B2",
            host: "127.0.0.1",
            port: boundPort
        )

        var buffer = [UInt8](repeating: 0, count: 256)
        let receivedCount = buffer.withUnsafeMutableBufferPointer { pointer in
            recv(socketFileDescriptor, pointer.baseAddress, pointer.count, 0)
        }

        try await sendResult
        try #require(receivedCount == 102)

        let receivedPacket = Array(buffer.prefix(receivedCount))
        let expectedPacket = try Array(WakeOnLanClient.magicPacket(macAddress: "D8-43-AE-2C-9D-B2"))
        #expect(receivedPacket == expectedPacket)
    }
}
