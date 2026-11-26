import SwiftUI

struct CalendarGridView: View {
    let layout: CalendarLayout
    let range: CalendarRange
    let selectedMarkID: String?
    @Binding var visibleStartDate: Date?
    let onSelect: (String) -> Void

    private let axisWidth: CGFloat = 42
    private let rightInset: CGFloat = 16
    private let headerHeight: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = max(1, proxy.size.width - axisWidth - rightInset)
            let dayWidth = viewportWidth / CGFloat(range.rawValue)
            let plotWidth = max(viewportWidth, CGFloat(layout.days.count) * dayWidth)
            let plotHeight = max(1, proxy.size.height - headerHeight)
            HStack(spacing: 0) {
                CalendarTimeAxis(layout: layout, height: plotHeight)
                    .frame(width: axisWidth)
                    .padding(.top, headerHeight)
                ScrollView(.horizontal) {
                    VStack(spacing: 0) {
                        CalendarDayHeader(days: layout.days, range: range, width: plotWidth)
                            .frame(height: headerHeight)
                        CalendarPlot(
                            layout: layout,
                            width: plotWidth,
                            height: plotHeight,
                            selectedMarkID: selectedMarkID,
                            onSelect: onSelect
                        )
                    }
                    .frame(width: plotWidth)
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.trailing)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $visibleStartDate, anchor: .leading)
                .frame(width: viewportWidth)
            }
        }
    }
}

private struct CalendarDayHeader: View {
    let days: [CalendarDayColumn]
    let range: CalendarRange
    let width: CGFloat
    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 1) {
                    if range != .thirty {
                        Text(CalendarText.weekday(day.id)).font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(BabyLogTheme.mutedText)
                    }
                    Text(CalendarText.day(day.id))
                        .font(.system(size: range == .thirty ? 8 : 11, weight: .bold))
                        .foregroundStyle(day.isToday ? .white : BabyLogTheme.ink)
                        .padding(.horizontal, day.isToday ? 4 : 0)
                        .padding(.vertical, day.isToday ? 2 : 0)
                        .background(day.isToday ? BabyLogTheme.brown800 : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(width: width / CGFloat(max(days.count, 1)))
                .id(day.id)
            }
        }
        .scrollTargetLayout()
    }
}

private struct CalendarTimeAxis: View {
    let layout: CalendarLayout
    let height: CGFloat
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<13, id: \.self) { index in
                Text(CalendarText.axisTime(layout.interval.start.addingTimeInterval(Double(index) * 7_200)))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .offset(y: CGFloat(index) * height / 12 - 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 6)
    }
}

private struct CalendarPlot: View {
    let layout: CalendarLayout
    let width: CGFloat
    let height: CGFloat
    let selectedMarkID: String?
    let onSelect: (String) -> Void

    var body: some View {
        let columnWidth = width / CGFloat(max(layout.days.count, 1))
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(layout.days) { day in
                    Rectangle()
                        .fill(day.isToday ? BabyLogTheme.brown100.opacity(0.72) : Color.clear)
                        .overlay(alignment: .leading) { Rectangle().fill(BabyLogTheme.divider).frame(width: 1) }
                        .frame(width: columnWidth)
                }
            }
            ForEach(0..<13, id: \.self) { index in
                Rectangle().fill(BabyLogTheme.divider).frame(width: width, height: 1)
                    .offset(y: CGFloat(index) * height / 12)
            }
            ForEach(layout.marks) { mark in
                let dayIndex = layout.days.firstIndex { $0.id == mark.dayID } ?? 0
                let frame = CalendarGeometryService.frame(for: mark, gridHeight: height)
                let metrics = CalendarMarkMetrics(kind: mark.kind, columnWidth: columnWidth)
                Button { onSelect(mark.id) } label: {
                    CalendarMarkBody(
                        mark: mark,
                        height: max(metrics.minimumHeight, frame.height),
                        radius: metrics.radius,
                        isSelected: selectedMarkID == mark.id
                    )
                }
                .buttonStyle(.plain)
                .frame(width: metrics.width, height: max(metrics.minimumHeight, frame.height))
                .offset(
                    x: CGFloat(dayIndex) * columnWidth + metrics.leading,
                    y: frame.y
                )
                .zIndex(mark.zIndex)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }
}

private struct CalendarMarkBody: View {
    let mark: CalendarMark
    let height: CGFloat
    let radius: CGFloat
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(mark.category.style.main.opacity(mark.kind == .sleep && mark.isContinuation ? 0.52 : 0.92))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: radius).stroke(BabyLogTheme.brown900, lineWidth: 2)
                }
            }
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    ForEach(mark.soothingTimes, id: \.self) { time in
                        SoothingBreakShape()
                            .stroke(BabyLogTheme.cream, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(height: 5)
                            .offset(y: max(0, min(
                                height - 5,
                                CGFloat(CalendarGeometryService.soothingOffset(
                                    for: time,
                                    in: mark,
                                    markHeight: Double(height)
                                )) - 2.5
                            )))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
    }
}

private struct SoothingBreakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(2, rect.width / 6)
        path.move(to: CGPoint(x: 0, y: rect.midY))
        var x = step
        var rises = true
        while x < rect.width {
            path.addLine(to: CGPoint(x: x, y: rises ? rect.minY : rect.maxY))
            rises.toggle()
            x += step
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct CalendarMarkMetrics {
    let width: CGFloat
    let leading: CGFloat
    let minimumHeight: CGFloat
    let radius: CGFloat
    init(kind: CalendarMarkKind, columnWidth: CGFloat) {
        let proportion: CGFloat
        switch kind {
        case .sleep: proportion = 0.76; minimumHeight = 5; radius = 3
        case .pump: proportion = 0.56; minimumHeight = 5; radius = 2
        case .feed: proportion = 0.94; minimumHeight = 4; radius = 2
        case .diaper: proportion = 0.60; minimumHeight = 3; radius = 2
        case .other: proportion = 0.14; minimumHeight = 6; radius = 3
        }
        width = max(kind == .other ? 6 : 2, columnWidth * proportion)
        leading = (columnWidth - width) / 2
    }
}
