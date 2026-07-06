import SwiftUI

struct WakeRemoteView: View {
    private enum Defaults {
        static let host = "70.18.244.191"
        static let port = "40009"
        static let macAddress = "D8-43-AE-2C-9D-B2"
    }

    private enum SendStatus: String {
        case ready
        case sending
        case sent
        case failed
    }

    @AppStorage(WakeSettingsKeys.host) private var host = Defaults.host
    @AppStorage(WakeSettingsKeys.port) private var port = Defaults.port
    @AppStorage(WakeSettingsKeys.macAddress) private var macAddress = Defaults.macAddress
    @AppStorage(WakeSettingsKeys.lastSentTimestamp) private var lastSentTimestamp = 0.0

    @State private var status = SendStatus.ready
    @State private var statusDetail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Victor PC Remote") {
                    TextField("Host/IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .accessibilityIdentifier("hostField")

                    TextField("UDP port", text: $port)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .accessibilityIdentifier("portField")

                    TextField("MAC address", text: $macAddress)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textContentType(.none)
                        .accessibilityIdentifier("macAddressField")
                }

                Section {
                    Button {
                        sendWakePacket()
                    } label: {
                        Label(buttonTitle, systemImage: "power")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(status == .sending)
                    .accessibilityIdentifier("wakeButton")

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(status.rawValue)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("statusValue")
                    }

                    HStack {
                        Text("Last sent")
                        Spacer()
                        Text(lastSentText)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("lastSentValue")
                    }

                    if !statusDetail.isEmpty {
                        Text(statusDetail)
                            .font(.footnote)
                            .foregroundStyle(status == .failed ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("Victor Wake")
        }
    }

    private var buttonTitle: String {
        status == .sending ? "Sending" : "Wake"
    }

    private var lastSentText: String {
        guard lastSentTimestamp > 0 else {
            return "Never"
        }

        let date = Date(timeIntervalSince1970: lastSentTimestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func sendWakePacket() {
        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPortText = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMACAddress = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let currentPort = UInt16(currentPortText), currentPort > 0 else {
            status = .failed
            statusDetail = WakeOnLanError.invalidPort.localizedDescription
            return
        }

        status = .sending
        statusDetail = "Sending magic packet."

        Task {
            do {
                try await WakeOnLanClient().sendMagicPacket(
                    macAddress: currentMACAddress,
                    host: currentHost,
                    port: currentPort
                )

                await MainActor.run {
                    status = .sent
                    statusDetail = "Magic packet sent."
                    lastSentTimestamp = Date().timeIntervalSince1970
                }
            } catch {
                await MainActor.run {
                    status = .failed
                    statusDetail = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    WakeRemoteView()
}
