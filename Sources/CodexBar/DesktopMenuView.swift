import CodexBarCore
import SwiftUI

@MainActor
struct DesktopMenuView: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let updater: UpdaterProviding
    @Bindable var selection: PreferencesSelection
    let managedCodexAccountCoordinator: ManagedCodexAccountCoordinator
    let codexAccountPromotionCoordinator: CodexAccountPromotionCoordinator
    let runProviderLoginFlow: @MainActor (UsageProvider) async -> Void
    @State private var searchText = ""
    @State private var hoveredTab: PreferencesTab?
    @State private var isRefreshHovering = false
    @FocusState private var searchFocused: Bool
    @Namespace private var selectionNamespace

    init(
        settings: SettingsStore,
        store: UsageStore,
        updater: UpdaterProviding,
        selection: PreferencesSelection,
        managedCodexAccountCoordinator: ManagedCodexAccountCoordinator = ManagedCodexAccountCoordinator(),
        codexAccountPromotionCoordinator: CodexAccountPromotionCoordinator? = nil,
        runProviderLoginFlow: @escaping @MainActor (UsageProvider) async -> Void = { _ in })
    {
        self.settings = settings
        self.store = store
        self.updater = updater
        self.selection = selection
        self.managedCodexAccountCoordinator = managedCodexAccountCoordinator
        self.codexAccountPromotionCoordinator = codexAccountPromotionCoordinator
            ?? CodexAccountPromotionCoordinator(
                settingsStore: settings,
                usageStore: store,
                managedAccountCoordinator: managedCodexAccountCoordinator)
        self.runProviderLoginFlow = runProviderLoginFlow
    }

    var body: some View {
        HStack(spacing: 0) {
            self.sidebar
            DesktopMenuSeparator()
            self.content
        }
        .desktopMenuCardPresentation()
        .frame(minWidth: DesktopMenuDesign.windowMinWidth, idealWidth: DesktopMenuDesign.windowIdealWidth)
        .frame(minHeight: DesktopMenuDesign.windowMinHeight, idealHeight: DesktopMenuDesign.windowIdealHeight)
        .background(DesktopMenuMaterialBackground())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                DesktopMenuStatusPill(
                    title: "\(self.store.enabledProviders().count)",
                    subtitle: "providers",
                    systemImage: "circle.grid.2x2")
                Button {
                    self.refreshUsage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolRenderingMode(.hierarchical)
                }
                .help("Refresh usage")
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            self.ensureValidSelection()
        }
        .onChange(of: self.searchText) { _, _ in
            self.selectFirstFilteredTabIfNeeded()
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidSelection()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DesktopMenuDesign.sidebarSpacing) {
            DesktopMenuBrandBlock(
                enabledProviderCount: self.store.enabledProviders().count,
                debugMenuEnabled: self.settings.debugMenuEnabled)

            DesktopMenuSearchField(
                text: self.$searchText,
                isFocused: self.$searchFocused)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: DesktopMenuDesign.rowSpacing) {
                Text("Settings")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                if self.filteredTabs.isEmpty {
                    DesktopMenuEmptySearch()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    ForEach(self.filteredTabs, id: \.self) { tab in
                        DesktopMenuSidebarRow(
                            tab: tab,
                            subtitle: Self.subtitle(for: tab),
                            systemImage: Self.systemImage(for: tab),
                            isSelected: tab == self.activeTab,
                            isHovered: tab == self.hoveredTab,
                            namespace: self.selectionNamespace)
                            .contentShape(RoundedRectangle(
                                cornerRadius: DesktopMenuDesign.selectionRadius,
                                style: .continuous))
                            .onTapGesture {
                                self.select(tab)
                            }
                            .onHover { isHovering in
                                withAnimation(DesktopMenuDesign.hoverAnimation) {
                                    self.hoveredTab = isHovering ? tab : nil
                                }
                            }
                    }
                }
            }
            .animation(DesktopMenuDesign.contentAnimation, value: self.filteredTabs)

            Spacer(minLength: 0)

            DesktopMenuSidebarFooter(
                selectedTab: self.activeTab,
                enabledProviderCount: self.store.enabledProviders().count)
        }
        .padding(DesktopMenuDesign.sidebarPadding)
        .frame(width: DesktopMenuDesign.sidebarWidth)
        .background(DesktopMenuSidebarBackground())
    }

    private var content: some View {
        VStack(spacing: 0) {
            DesktopMenuTopBar(
                tab: self.activeTab,
                subtitle: Self.subtitle(for: self.activeTab),
                systemImage: Self.systemImage(for: self.activeTab),
                enabledProviderCount: self.store.enabledProviders().count,
                isRefreshHovering: self.isRefreshHovering,
                refresh: self.refreshUsage)
                .onHover { isHovering in
                    withAnimation(DesktopMenuDesign.hoverAnimation) {
                        self.isRefreshHovering = isHovering
                    }
                }

            ZStack(alignment: .topLeading) {
                DesktopMenuContentBackdrop()
                self.detailView(for: self.activeTab)
                    .id(self.activeTab)
                    .id(self.settings.appLanguage)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .frame(minWidth: 560, idealWidth: self.activeTab.preferredWidth, maxWidth: .infinity)
                    .frame(minHeight: 480, idealHeight: self.activeTab.preferredHeight, maxHeight: .infinity)
                    .padding(.horizontal, DesktopMenuDesign.contentPadding)
                    .padding(.bottom, DesktopMenuDesign.contentPadding)
            }
            .animation(DesktopMenuDesign.contentAnimation, value: self.activeTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var filteredTabs: [PreferencesTab] {
        Self.filteredTabs(
            searchText: self.searchText,
            debugMenuEnabled: self.settings.debugMenuEnabled)
    }

    static func visibleTabs(settings: SettingsStore) -> [PreferencesTab] {
        self.visibleTabs(debugMenuEnabled: settings.debugMenuEnabled)
    }

    static func visibleTabs(debugMenuEnabled: Bool) -> [PreferencesTab] {
        PreferencesTab.allCases.filter { tab in
            debugMenuEnabled || tab != .debug
        }
    }

    static func normalizedTab(_ tab: PreferencesTab, debugMenuEnabled: Bool) -> PreferencesTab {
        if tab == .debug, !debugMenuEnabled {
            return .general
        }
        return tab
    }

    static func filteredTabs(searchText: String, debugMenuEnabled: Bool) -> [PreferencesTab] {
        let tabs = self.visibleTabs(debugMenuEnabled: debugMenuEnabled)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !query.isEmpty else { return tabs }
        return tabs.filter { tab in
            tab.title.localizedLowercase.contains(query) ||
                self.subtitle(for: tab).localizedLowercase.contains(query)
        }
    }

    private var selectedTab: Binding<PreferencesTab?> {
        Binding(
            get: { self.selection.tab },
            set: { newValue in
                if let newValue {
                    self.selection.tab = newValue
                }
            })
    }

    private var activeTab: PreferencesTab {
        Self.normalizedTab(self.selection.tab, debugMenuEnabled: self.settings.debugMenuEnabled)
    }

    private func ensureValidSelection() {
        let normalized = Self.normalizedTab(self.selection.tab, debugMenuEnabled: self.settings.debugMenuEnabled)
        if normalized != self.selection.tab {
            self.selection.tab = normalized
        }
    }

    private func select(_ tab: PreferencesTab) {
        withAnimation(DesktopMenuDesign.selectionAnimation) {
            self.selection.tab = Self.normalizedTab(tab, debugMenuEnabled: self.settings.debugMenuEnabled)
        }
    }

    private func selectFirstFilteredTabIfNeeded() {
        guard !self.filteredTabs.isEmpty,
              !self.filteredTabs.contains(self.activeTab)
        else { return }
        self.select(self.filteredTabs[0])
    }

    private static func systemImage(for tab: PreferencesTab) -> String {
        switch tab {
        case .general: "gearshape"
        case .providers: "square.grid.2x2"
        case .display: "eye"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        case .debug: "ladybug"
        }
    }

    static func subtitle(for tab: PreferencesTab) -> String {
        switch tab {
        case .general: "Language, launch, refresh, and notifications"
        case .providers: "Accounts, API keys, cookies, and provider order"
        case .display: "Menu bar layout, usage rows, and overview"
        case .advanced: "Diagnostics, paths, and expert controls"
        case .about: "Version, updates, links, and credits"
        case .debug: "Developer diagnostics and verbose logging"
        }
    }

    private func refreshUsage() {
        Task {
            await ProviderInteractionContext.$current.withValue(.userInitiated) {
                await self.store.refresh(forceTokenUsage: true)
            }
        }
    }

    @ViewBuilder
    private func detailView(for tab: PreferencesTab) -> some View {
        switch tab {
        case .general:
            GeneralPane(settings: self.settings, store: self.store)
        case .providers:
            ProvidersPane(
                settings: self.settings,
                store: self.store,
                managedCodexAccountCoordinator: self.managedCodexAccountCoordinator,
                codexAccountPromotionCoordinator: self.codexAccountPromotionCoordinator,
                runProviderLoginFlow: self.runProviderLoginFlow)
        case .display:
            DisplayPane(settings: self.settings, store: self.store)
        case .advanced:
            AdvancedPane(settings: self.settings)
        case .about:
            AboutPane(updater: self.updater)
        case .debug:
            DebugPane(settings: self.settings, store: self.store)
        }
    }
}

private enum DesktopMenuDesign {
    static let windowMinWidth: CGFloat = 940
    static let windowIdealWidth: CGFloat = 1080
    static let windowMinHeight: CGFloat = 650
    static let windowIdealHeight: CGFloat = 740
    static let sidebarWidth: CGFloat = 300
    static let sidebarPadding: CGFloat = 16
    static let sidebarSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 6
    static let contentPadding: CGFloat = 22
    static let selectionRadius: CGFloat = 16
    static let panelRadius: CGFloat = 24
    static let searchRadius: CGFloat = 15
    static let hoverAnimation = Animation.easeOut(duration: 0.16)
    static let selectionAnimation = Animation.spring(response: 0.28, dampingFraction: 0.84)
    static let contentAnimation = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let separatorOpacity: Double = 0.08
    static let cardFillOpacity: Double = 0.58
    static let hoverFillOpacity: Double = 0.08
    static let selectionFillOpacity: Double = 0.14
}

private struct DesktopMenuBrandBlock: View {
    let enabledProviderCount: Int
    let debugMenuEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.regularMaterial)
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("CodexBar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("AI usage command center")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 7) {
                DesktopMenuChip(text: "\(self.enabledProviderCount) providers", systemImage: "circle.grid.2x2")
                if self.debugMenuEnabled {
                    DesktopMenuChip(text: "Debug", systemImage: "ladybug")
                }
            }
        }
        .padding(14)
        .background(DesktopMenuGlassPanel(cornerRadius: 22, emphasis: .hero))
    }
}

private struct DesktopMenuSearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(self.isFocused.wrappedValue ? .primary : .secondary)

            TextField("Search settings", text: self.$text)
                .textFieldStyle(.plain)
                .focused(self.isFocused)
                .font(.callout)

            if self.text.isEmpty {
                Text("⌘K")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Button {
                    withAnimation(DesktopMenuDesign.hoverAnimation) {
                        self.text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: DesktopMenuDesign.searchRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DesktopMenuDesign.searchRadius, style: .continuous)
                        .stroke(
                            self.isFocused.wrappedValue
                                ? Color.accentColor.opacity(0.55)
                                : .white.opacity(self.isHovering ? 0.18 : 0.10),
                            lineWidth: self.isFocused.wrappedValue ? 1.1 : 0.8)
                }
                .shadow(
                    color: self.isFocused.wrappedValue ? Color.accentColor.opacity(0.14) : .black.opacity(0.045),
                    radius: self.isFocused.wrappedValue ? 18 : 10,
                    y: 5)
        }
        .onHover { hovering in
            withAnimation(DesktopMenuDesign.hoverAnimation) {
                self.isHovering = hovering
            }
        }
        .animation(DesktopMenuDesign.hoverAnimation, value: self.isFocused.wrappedValue)
    }
}

private struct DesktopMenuSidebarRow: View {
    let tab: PreferencesTab
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if self.isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.primary.opacity(DesktopMenuDesign.selectionFillOpacity))
                } else if self.isHovered {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.primary.opacity(DesktopMenuDesign.hoverFillOpacity))
                }
                Image(systemName: self.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(self.isSelected ? .primary : .secondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.tab.title)
                    .font(.callout.weight(self.isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Text(self.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 6)

            if self.isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if self.isSelected {
                RoundedRectangle(cornerRadius: DesktopMenuDesign.selectionRadius, style: .continuous)
                    .fill(.primary.opacity(DesktopMenuDesign.selectionFillOpacity))
                    .matchedGeometryEffect(id: "selected-tab-capsule", in: self.namespace)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesktopMenuDesign.selectionRadius, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
            } else if self.isHovered {
                RoundedRectangle(cornerRadius: DesktopMenuDesign.selectionRadius, style: .continuous)
                    .fill(.primary.opacity(DesktopMenuDesign.hoverFillOpacity))
            }
        }
        .scaleEffect(self.isHovered && !self.isSelected ? 1.006 : 1)
        .animation(DesktopMenuDesign.hoverAnimation, value: self.isHovered)
        .animation(DesktopMenuDesign.selectionAnimation, value: self.isSelected)
    }
}

private struct DesktopMenuTopBar: View {
    let tab: PreferencesTab
    let subtitle: String
    let systemImage: String
    let enabledProviderCount: Int
    let isRefreshHovering: Bool
    let refresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                Image(systemName: self.systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 52, height: 52)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.8)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(self.tab.title)
                    .font(.title2.weight(.semibold))
                Text(self.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            DesktopMenuStatusPill(
                title: "\(self.enabledProviderCount)",
                subtitle: "enabled",
                systemImage: "checkmark.circle")

            Button {
                self.refresh()
            } label: {
                PhaseAnimator([0, 1], trigger: self.isRefreshHovering) { phase in
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .rotationEffect(.degrees(phase == 1 ? 24 : 0))
                        .frame(width: 34, height: 34)
                } animation: { _ in
                    DesktopMenuDesign.hoverAnimation
                }
            }
            .buttonStyle(.plain)
            .background(DesktopMenuGlassPanel(cornerRadius: 13, emphasis: self.isRefreshHovering ? .elevated : .normal))
            .help("Refresh usage")
        }
        .padding(.horizontal, DesktopMenuDesign.contentPadding)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct DesktopMenuChip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(self.text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesktopMenuGlassPanel(cornerRadius: 10, emphasis: .flat))
    }
}

private struct DesktopMenuStatusPill: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: self.systemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(self.title)
                .font(.caption.weight(.semibold))
            Text(self.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(DesktopMenuGlassPanel(cornerRadius: 13, emphasis: .normal))
    }
}

private struct DesktopMenuSidebarFooter: View {
    let selectedTab: PreferencesTab
    let enabledProviderCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green.gradient)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.45), radius: 7)
                Text("Menu bar active")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(self.enabledProviderCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("Current section: \(self.selectedTab.title)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(DesktopMenuGlassPanel(cornerRadius: 18, emphasis: .flat))
    }
}

private struct DesktopMenuEmptySearch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
            Text("No results")
                .font(.callout.weight(.semibold))
            Text("Search settings, providers, display, or diagnostics.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesktopMenuGlassPanel(cornerRadius: 18, emphasis: .flat))
    }
}

private struct DesktopMenuSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(DesktopMenuDesign.separatorOpacity))
            .frame(width: 1)
    }
}

private struct DesktopMenuContentBackdrop: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.primary.opacity(0.035))
                .padding(.horizontal, 12)
                .padding(.top, 8)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
        .allowsHitTesting(false)
    }
}

private struct DesktopMenuSidebarBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.09),
                    Color.accentColor.opacity(0.075),
                    Color.black.opacity(0.045),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

private enum DesktopMenuGlassEmphasis {
    case flat
    case normal
    case elevated
    case hero

    var shadowOpacity: Double {
        switch self {
        case .flat: 0.0
        case .normal: 0.025
        case .elevated: 0.06
        case .hero: 0.08
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .flat: 0
        case .normal: 8
        case .elevated: 12
        case .hero: 16
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .flat: 0.09
        case .normal: 0.13
        case .elevated: 0.19
        case .hero: 0.22
        }
    }
}

private struct DesktopMenuGlassPanel: View {
    let cornerRadius: CGFloat
    var emphasis: DesktopMenuGlassEmphasis = .normal

    var body: some View {
        RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
            .fill(self.fillStyle)
            .overlay {
                RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(self.emphasis.strokeOpacity), lineWidth: 0.8)
            }
            .shadow(
                color: .black.opacity(self.emphasis.shadowOpacity),
                radius: self.emphasis.shadowRadius,
                y: self.emphasis == .flat ? 3 : 8)
    }

    private var fillStyle: AnyShapeStyle {
        switch self.emphasis {
        case .flat, .normal:
            AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(DesktopMenuDesign.cardFillOpacity))
        case .elevated, .hero:
            AnyShapeStyle(.thinMaterial)
        }
    }
}

private struct DesktopMenuMaterialBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.12),
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
        .desktopMenuLiquidGlassCompatibility()
        .ignoresSafeArea()
    }
}

extension View {
    fileprivate func desktopMenuLiquidGlassCompatibility() -> some View {
        self.modifier(DesktopMenuLiquidGlassCompatibilityModifier())
    }
}

private struct DesktopMenuLiquidGlassCompatibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Keep the macOS 26 branch isolated. The current public SDK used by CI may not
            // expose glassEffect yet, so the branch keeps the call site ready without
            // referencing unavailable symbols.
            content
        } else {
            content
        }
    }
}
