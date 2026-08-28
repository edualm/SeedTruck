//
//  AddMagnetView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct TorrentImportActionBar<Status: View, PrimaryLabel: View>: View {

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    let cancelAction: () -> Void
    let primaryAction: () -> Void
    let cancelDisabled: Bool
    let primaryDisabled: Bool
    let cancelAccessibilityIdentifier: String
    let primaryAccessibilityIdentifier: String

    private let status: Status
    private let primaryLabel: PrimaryLabel

    init(
        cancelAction: @escaping () -> Void,
        primaryAction: @escaping () -> Void,
        cancelDisabled: Bool = false,
        primaryDisabled: Bool,
        cancelAccessibilityIdentifier: String,
        primaryAccessibilityIdentifier: String,
        @ViewBuilder status: () -> Status,
        @ViewBuilder primaryLabel: () -> PrimaryLabel
    ) {
        self.cancelAction = cancelAction
        self.primaryAction = primaryAction
        self.cancelDisabled = cancelDisabled
        self.primaryDisabled = primaryDisabled
        self.cancelAccessibilityIdentifier = cancelAccessibilityIdentifier
        self.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        self.status = status()
        self.primaryLabel = primaryLabel()
    }

    private var expandsButtons: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        24
        #else
        16
        #endif
    }

    private var verticalPadding: CGFloat {
        #if os(macOS)
        14
        #else
        12
        #endif
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: cancelAction) {
                Text("Cancel")
                    .frame(maxWidth: expandsButtons ? .infinity : nil)
                    .fixedSize(horizontal: !expandsButtons, vertical: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)
            .disabled(cancelDisabled)
            .accessibilityIdentifier(cancelAccessibilityIdentifier)

            Button(action: primaryAction) {
                primaryLabel
                    .frame(minWidth: 140)
                    .frame(maxWidth: expandsButtons ? .infinity : nil)
                    .fixedSize(horizontal: !expandsButtons, vertical: false)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(primaryDisabled)
            .accessibilityIdentifier(primaryAccessibilityIdentifier)
        }
        .frame(maxWidth: expandsButtons ? .infinity : nil)
        .layoutPriority(1)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if expandsButtons {
                VStack(alignment: .leading, spacing: 12) {
                    status
                    actionButtons
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        status
                        Spacer(minLength: 12)
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        status
                        HStack {
                            Spacer(minLength: 0)
                            actionButtons
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

struct AddMagnetView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    @State private var magnetLink: String = ""
    @State private var navigationLinkActive = false
    @State private var validationErrorMessage: String?
    @State private var validatedTorrent: LocalTorrent?
    
    @Binding var server: Server?
    
    private var canProceed: Bool {
        !magnetLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var baseMagnetTextField: some View {
        TextField("magnet:?xt=urn:btih:...", text: $magnetLink)
            .textFieldStyle(.plain)
            .onSubmit {
                if canProceed {
                    proceed()
                }
            }
            .onChange(of: magnetLink) {
                validationErrorMessage = nil
            }
            .accessibilityLabel("Magnet Link")
            .accessibilityHint("Paste the complete magnet link")
            .accessibilityIdentifier("magnet-link-input")
    }

    @ViewBuilder
    private var magnetTextField: some View {
        #if os(iOS)
        baseMagnetTextField
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .submitLabel(.continue)
        #else
        baseMagnetTextField
        #endif
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 64, height: 64)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .accessibilityHidden(true)

                Text("Paste a Magnet Link")
                    .font(.title2.weight(.semibold))

                Text("SeedTruck will validate the link before you choose where to download it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Magnet Link")
                    .font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    magnetTextField
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            validationErrorMessage == nil
                                ? Color.secondary.opacity(0.2)
                                : Color.red,
                            lineWidth: 1
                        )
                }

                if let validationErrorMessage {
                    Label(validationErrorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("magnet-validation-error")
                } else {
                    Text("Magnet links begin with magnet: and can be copied from most torrent indexes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(24)
        .background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
    }

    private var innerBody: some View {
        ScrollView {
            entryCard
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity)
        }
    }

    private var actionBar: some View {
        TorrentImportActionBar(
            cancelAction: { presentation.wrappedValue.dismiss() },
            primaryAction: proceed,
            primaryDisabled: !canProceed,
            cancelAccessibilityIdentifier: "magnet-cancel",
            primaryAccessibilityIdentifier: "magnet-proceed"
        ) {
            EmptyView()
        } primaryLabel: {
            Label("Proceed", systemImage: "arrow.right")
        }
    }

    @ViewBuilder
    private var torrentHandlerDestination: some View {
        if let validatedTorrent {
            TorrentHandlerView(
                torrent: validatedTorrent,
                server: server,
                dismissHandler: {
                    presentation.wrappedValue.dismiss()
                }
            )
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        innerBody
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .navigationTitle("Add Magnet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(isPresented: $navigationLinkActive) {
                torrentHandlerDestination
            }
    }

    private func proceed() {
        let value = magnetLink.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            guard let url = URL(string: value) else {
                throw TorrentImportError.unsupportedType
            }

            validatedTorrent = try LocalTorrent(validating: url)
            navigationLinkActive = true
        } catch {
            validationErrorMessage = error.localizedDescription
        }
    }
    
    @ViewBuilder
    var body: some View {
        NavigationStack {
            #if os(macOS)
            navigationContent
                .frame(minWidth: 500, idealWidth: 560, maxWidth: 640,
                       minHeight: 400, idealHeight: 500, maxHeight: 700)
            #else
            navigationContent
            #endif
        }
    }
}

struct AddMagnetView_Previews: PreviewProvider {
    
    static var previews: some View {
        AddMagnetView(server: .constant(PreviewMockData.server))
            .environmentObject(PreviewMockData.serverRepository)
    }
}

#if os(iOS)
struct AddMagnetView_iPad_Previews: PreviewProvider {

    static var previews: some View {
        AddMagnetView(server: .constant(PreviewMockData.server))
            .environmentObject(PreviewMockData.serverRepository)
            .previewDevice(PreviewDevice(rawValue: "iPad Air 13-inch (M4)"))
            .previewDisplayName("iPad")
    }
}
#endif
