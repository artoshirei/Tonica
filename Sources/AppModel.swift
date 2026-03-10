import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    var hoveredFocus: SegmentFocus?
    var selectedFocus: SegmentFocus?
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

    func label(for focus: SegmentFocus) -> String {
        slices[focus.index].label(for: focus.ring)
    }

    func updateHover(_ focus: SegmentFocus, isHovering: Bool) {
        if isHovering {
            hoveredFocus = focus
        } else if hoveredFocus == focus {
            hoveredFocus = nil
        }
    }

    func select(_ focus: SegmentFocus) {
        selectedFocus = focus
    }

    func selectCurrentRing(_ ring: RingKind, from focus: SegmentFocus) {
        selectedFocus = SegmentFocus(index: focus.index, ring: ring)
    }

    func clearSelection() {
        selectedFocus = nil
    }

    func previousSlice(for index: Int) -> CircleSlice {
        slices[(index - 1 + slices.count) % slices.count]
    }

    func nextSlice(for index: Int) -> CircleSlice {
        slices[(index + 1) % slices.count]
    }
}
