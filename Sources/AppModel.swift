import Observation
import SwiftUI

enum InspectorVisibility: Equatable {
    case hidden
    case preview
    case expanded
}

@MainActor
@Observable
final class AppModel {
    var hoveredFocus: SegmentFocus?
    var selectedFocus: SegmentFocus?
    var inspectorVisibility: InspectorVisibility = .hidden
    var isPanelVisible = false
    var theme: PanelTheme = AppPreferences.loadTheme() {
        didSet {
            AppPreferences.saveTheme(theme)
        }
    }
    var shortcutDescription: String = PanelHotKey.description

    let slices = CircleSlice.all

    var activeFocus: SegmentFocus? {
        hoveredFocus ?? selectedFocus
    }

    var activeSlice: CircleSlice? {
        guard let activeFocus else { return nil }
        return slices[activeFocus.index]
    }

    var inspectorPreviewFocus: SegmentFocus? {
        guard inspectorVisibility == .preview else { return nil }
        return selectedFocus
    }

    var inspectorDetailFocus: SegmentFocus? {
        guard inspectorVisibility == .expanded else { return nil }
        return selectedFocus
    }

    func label(for focus: SegmentFocus) -> String {
        slices[focus.index].label(for: focus.ring)
    }

    func updateHover(_ focus: SegmentFocus?) {
        guard hoveredFocus != focus else { return }
        hoveredFocus = focus
        syncInspectorState()
    }

    func select(_ focus: SegmentFocus) {
        let selectionChanged = selectedFocus != focus
        selectedFocus = focus
        if !selectionChanged {
            if inspectorVisibility == .preview {
                inspectorVisibility = .expanded
            }
            return
        }
        inspectorVisibility = .preview
    }

    func selectCurrentRing(_ ring: RingKind, from focus: SegmentFocus) {
        let wasExpanded = inspectorVisibility == .expanded
        selectedFocus = SegmentFocus(index: focus.index, ring: ring)
        inspectorVisibility = wasExpanded ? .expanded : .preview
    }

    func selectFromInspector(_ focus: SegmentFocus) {
        selectedFocus = focus
        inspectorVisibility = .expanded
    }

    func clearSelection() {
        selectedFocus = nil
        syncInspectorState()
    }

    func expandInspector() {
        guard selectedFocus != nil else { return }
        inspectorVisibility = .expanded
    }

    func collapseInspector() {
        if selectedFocus != nil {
            inspectorVisibility = .preview
        } else {
            inspectorVisibility = .hidden
        }
    }

    func dismissInspector() {
        selectedFocus = nil
        inspectorVisibility = .hidden
    }

    func previousSlice(for index: Int) -> CircleSlice {
        slices[(index - 1 + slices.count) % slices.count]
    }

    func nextSlice(for index: Int) -> CircleSlice {
        slices[(index + 1) % slices.count]
    }

    private func syncInspectorState() {
        guard selectedFocus == nil else { return }
        inspectorVisibility = .hidden
    }
}
