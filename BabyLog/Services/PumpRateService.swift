import Foundation

/// Production rate = amount pumped ÷ time since the *previous* pump session
/// ended (not this session's own timer duration) — a milk-production metric,
/// not a pump-mechanics pace. Returns raw mL/hr; callers format the final
/// string via `VolumeService.displayString(milliliters:unit:)` so unit
/// conversion happens exactly once.
enum PumpRateService {
    static func millilitersPerHour(amountMl: Double, elapsedSeconds: TimeInterval) -> Double? {
        guard elapsedSeconds > 0 else { return nil }
        return amountMl * 3_600 / elapsedSeconds
    }

    /// Rate for a single session, anchored to the end of the session that
    /// preceded it. `nil` when there is no previous session (the baby's
    /// first-ever pump, or one not yet loaded at a window boundary) — display
    /// that as "–".
    static func sessionRate(_ session: PumpSession, previousSessionEndTime: Date?) -> Double? {
        guard let previousSessionEndTime else { return nil }
        return millilitersPerHour(
            amountMl: session.totalAmountMl,
            elapsedSeconds: session.endTime.timeIntervalSince(previousSessionEndTime)
        )
    }

    /// Rate for a group of sessions (e.g. one day): total amount across the
    /// group ÷ time from the end of the pump immediately before the group's
    /// first session, to the end of the group's last session.
    static func groupRate(totalAmountMl: Double, lastEndTime: Date, previousGroupEndTime: Date?) -> Double? {
        guard let previousGroupEndTime else { return nil }
        return millilitersPerHour(
            amountMl: totalAmountMl,
            elapsedSeconds: lastEndTime.timeIntervalSince(previousGroupEndTime)
        )
    }

    /// Time-weighted average across contiguous clean-pump blocks. A
    /// post-nursing pump ends the current block. Each block begins at the end
    /// of the pump immediately before its first clean session and ends at the
    /// last clean pump in that block. Blocks without a preceding pump cannot
    /// produce a rate and are omitted.
    static func weightedCleanRate(
        sessions: [PumpSession],
        sessionImmediatelyBeforeRange: PumpSession? = nil
    ) -> Double? {
        let ordered = sessions.sorted { $0.startTime < $1.startTime }
        var prior = sessionImmediatelyBeforeRange
        var block: [PumpSession] = []
        var weightedRateTotal = 0.0
        var elapsedTotal: TimeInterval = 0

        func addBlock(_ values: [PumpSession], previous: PumpSession?) -> (Double, TimeInterval) {
            guard let previous, let last = values.last else { return (0, 0) }
            let elapsed = last.endTime.timeIntervalSince(previous.endTime)
            let amount = values.reduce(0) { $0 + $1.totalAmountMl }
            guard elapsed > 0, let rate = millilitersPerHour(amountMl: amount, elapsedSeconds: elapsed) else { return (0, 0) }
            return (rate * elapsed, elapsed)
        }

        var blockPrevious = prior
        for session in ordered {
            if session.isPostNursing {
                let contribution = addBlock(block, previous: blockPrevious)
                weightedRateTotal += contribution.0; elapsedTotal += contribution.1
                block = []; prior = session; blockPrevious = session
            } else {
                if block.isEmpty { blockPrevious = prior }
                block.append(session)
                prior = session
            }
        }
        let contribution = addBlock(block, previous: blockPrevious)
        weightedRateTotal += contribution.0; elapsedTotal += contribution.1
        return elapsedTotal > 0 ? weightedRateTotal / elapsedTotal : nil
    }

    /// The session with the latest `startTime` strictly before `startTime`,
    /// excluding `id` (the session being edited, if any).
    static func previousSession(before startTime: Date, excluding id: String? = nil, in sessions: [PumpSession]) -> PumpSession? {
        sessions
            .filter { $0.startTime < startTime && $0.id != id }
            .max { $0.startTime < $1.startTime }
    }

    /// Anchor for a session's displayed rate. Post-nursing pumps start from the
    /// last milk removal — the later of the previous pump's end and the latest
    /// nursing that ended before this pump started. Averages never use this.
    static func rateAnchorEndTime(
        for session: PumpSession,
        previousPumpEndTime: Date?,
        nursingSessions: [NursingSession]
    ) -> Date? {
        guard session.isPostNursing else { return previousPumpEndTime }
        let nursingEnd = nursingSessions
            .map(\.endTime)
            .filter { $0 <= session.startTime }
            .max()
        switch (previousPumpEndTime, nursingEnd) {
        case let (pump?, nursing?): return max(pump, nursing)
        case let (pump, nursing): return pump ?? nursing
        }
    }
}

struct NursingEstimate: Equatable, Sendable {
    let averageMl: Double
    let minimumMl: Double
    let maximumMl: Double
}

enum NursingEstimateService {
    /// Estimates milk transferred during the most recent Nursing session
    /// preceding a post-nursing pump. The baseline is the arithmetic mean of
    /// up to five preceding clean single-session rates. The range uses the
    /// lowest and highest rates from that same sample.
    static func estimates(
        nursingSessions: [NursingSession],
        pumpSessions: [PumpSession]
    ) -> [String: NursingEstimate] {
        let pumps = pumpSessions.sorted { $0.startTime < $1.startTime }
        var result: [String: NursingEstimate] = [:]
        for (index, postPump) in pumps.enumerated() where postPump.isPostNursing {
            guard index > 0 else { continue }
            let previousPump = pumps[index - 1]
            let rates = (1..<index).compactMap { offset -> Double? in
                let session = pumps[offset]
                guard !session.isPostNursing else { return nil }
                return PumpRateService.sessionRate(
                    session,
                    previousSessionEndTime: pumps[offset - 1].endTime
                )
            }.suffix(5)
            guard let minimumRate = rates.min(), let maximumRate = rates.max() else { continue }
            let averageRate = rates.reduce(0, +) / Double(rates.count)
            let elapsed = postPump.endTime.timeIntervalSince(previousPump.endTime)
            guard elapsed > 0 else { continue }
            func estimatedAmount(using rate: Double) -> Double {
                max(0, rate * elapsed / 3_600 - postPump.totalAmountMl)
            }
            let sessionsBetween = nursingSessions
                .filter { $0.endTime <= postPump.startTime && $0.endTime >= previousPump.endTime }
            guard !sessionsBetween.isEmpty else { continue }
            // The estimate covers everything removed since the last pump, so split it evenly.
            let share = Double(sessionsBetween.count)
            for nursing in sessionsBetween {
                result[nursing.id] = NursingEstimate(
                    averageMl: estimatedAmount(using: averageRate) / share,
                    minimumMl: estimatedAmount(using: minimumRate) / share,
                    maximumMl: estimatedAmount(using: maximumRate) / share
                )
            }
        }
        return result
    }

    /// The clean-rate sample the next post-nursing estimate will use: up to the
    /// last five clean single-session rates. Rates are mL/hr.
    static func currentAverages(pumpSessions: [PumpSession]) -> NursingEstimateAverages? {
        let pumps = pumpSessions.sorted { $0.startTime < $1.startTime }
        guard pumps.count > 1 else { return nil }
        let rows = (1..<pumps.count).compactMap { offset -> (total: Double, left: Double?, right: Double?)? in
            let session = pumps[offset]
            guard !session.isPostNursing else { return nil }
            let elapsed = session.endTime.timeIntervalSince(pumps[offset - 1].endTime)
            guard let total = PumpRateService.millilitersPerHour(amountMl: session.totalAmountMl, elapsedSeconds: elapsed) else { return nil }
            func sideRate(_ amount: Double?) -> Double? {
                guard session.sideAmountsAreSpecified, let amount else { return nil }
                return PumpRateService.millilitersPerHour(amountMl: amount, elapsedSeconds: elapsed)
            }
            return (total, sideRate(session.leftAmountMl), sideRate(session.rightAmountMl))
        }.suffix(5)
        guard !rows.isEmpty else { return nil }
        return NursingEstimateAverages(
            sampleCount: rows.count,
            total: NursingRateStats(rows.map(\.total)),
            left: NursingRateStats(rows.compactMap(\.left)),
            right: NursingRateStats(rows.compactMap(\.right))
        )
    }
}

struct NursingRateStats: Equatable, Sendable {
    let average: Double
    let lowest: Double
    let highest: Double

    init?(_ values: [Double]) {
        guard let lowest = values.min(), let highest = values.max() else { return nil }
        self.lowest = lowest
        self.highest = highest
        average = values.reduce(0, +) / Double(values.count)
    }
}

struct NursingEstimateAverages: Equatable, Sendable {
    let sampleCount: Int
    let total: NursingRateStats?
    let left: NursingRateStats?
    let right: NursingRateStats?
}

enum PumpPostNursingDefaultService {
    /// The first pump after a nursing session is the only pump that receives
    /// the smart default. Saving that pump makes it the newest pump, so later
    /// pumps remain off until another nursing session is recorded.
    static func shouldDefaultOn(
        latestNursing: NursingSession?,
        latestPump: PumpSession?
    ) -> Bool {
        guard let latestNursing else { return false }
        return latestNursing.endTime > (latestPump?.endTime ?? .distantPast)
    }
}
