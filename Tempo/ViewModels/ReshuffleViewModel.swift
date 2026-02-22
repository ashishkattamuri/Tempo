import Foundation
import SwiftData
import Observation

/// ViewModel for the reshuffle flow.
/// Manages the analysis, proposal display, and change application.
@MainActor
@Observable
final class ReshuffleViewModel {
    // MARK: - Dependencies

    private let repository: ScheduleRepository
    private let engine = ReshuffleEngine()
    private let summaryGenerator = SummaryGenerator()

    // MARK: - State

    var isAnalyzing = false
    var result: ReshuffleResult?
    var error: Error?

    // User decisions for items requiring input
    var userDecisions: [UUID: Change.UserOption] = [:]

    // MARK: - Computed Properties

    var hasResult: Bool {
        result != nil
    }

    var hasChanges: Bool {
        guard let result = result else { return false }
        return result.changes.contains { change in
            if case .protected = change.action { return false }
            return true
        }
    }

    var canApply: Bool {
        guard let result = result else { return false }

        // Check all required decisions are made
        let requiresDecision = result.itemsRequiringDecision
        for change in requiresDecision {
            if userDecisions[change.item.id] == nil {
                return false
            }
        }

        return true
    }

    var quickSummary: String {
        guard let result = result else { return "" }
        return summaryGenerator.quickSummary(changes: result.changes)
    }

    var pendingDecisionsCount: Int {
        guard let result = result else { return 0 }
        let requiresDecision = result.itemsRequiringDecision
        let decidedCount = requiresDecision.filter { userDecisions[$0.item.id] != nil }.count
        return requiresDecision.count - decidedCount
    }

    // MARK: - Initialization

    init(repository: ScheduleRepository) {
        self.repository = repository
    }

    // MARK: - Analysis

    func analyze(items: [ScheduleItem], for date: Date) async {
        isAnalyzing = true
        error = nil
        userDecisions = [:]

        // Run analysis
        result = engine.analyze(items: items, for: date)

        isAnalyzing = false
    }

    // MARK: - User Decisions

    func makeDecision(for itemId: UUID, option: Change.UserOption) {
        userDecisions[itemId] = option
    }

    func clearDecision(for itemId: UUID) {
        userDecisions.removeValue(forKey: itemId)
    }

    // MARK: - Apply Changes

    func applyChanges() async throws {
        guard let result = result else { return }

        // Filter out changes that require user decision (those are handled separately)
        var changesToApply = result.changes.filter { change in
            if case .requiresUserDecision = change.action {
                return false
            }
            return true
        }

        // Add user-decided changes
        for change in result.itemsRequiringDecision {
            if let decision = userDecisions[change.item.id] {
                // Convert user decision to actual change
                // For now, we'll create a protected change as placeholder
                // In a real implementation, the decision would map to specific actions
                changesToApply.append(Change(
                    item: change.item,
                    action: .protected,
                    reason: "User chose: \(decision.title)"
                ))
            }
        }

        try await repository.applyChanges(changesToApply)

        // Reset state
        reset()
    }

    func reset() {
        result = nil
        userDecisions = [:]
        error = nil
    }

    // MARK: - Grouped Changes for Display

    var protectedChanges: [Change] {
        result?.protectedChanges ?? []
    }

    var adjustedChanges: [Change] {
        result?.resizedChanges ?? []
    }

    var movedChanges: [Change] {
        result?.movedChanges ?? []
    }

    var deferredChanges: [Change] {
        result?.deferredChanges ?? []
    }

    var decisionsNeeded: [Change] {
        result?.itemsRequiringDecision ?? []
    }
}
