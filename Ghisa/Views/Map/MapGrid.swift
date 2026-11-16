import SwiftUI

/// The grid of one room with its zones and machines. Scrolls in both directions and zooms with two fingers.
/// While editing, a tap on an empty cell adds an item and dragging moves it (zones are moved by their label).
struct MapGrid: View {
    let room: Room
    let editing: Bool
    let selected: UUID?
    let onTapCell: (_ column: Int, _ row: Int) -> Void
    let onTapItem: (MapItem) -> Void
    let onMove: (_ item: MapItem, _ column: Int, _ row: Int) -> Void

    @State private var cellSize: CGFloat = 46
    @GestureState private var pinch: CGFloat = 1
    @State private var dragged: UUID?
    @State private var dragOffset: CGSize = .zero

    /// Space for the letters above and the numbers on the left.
    private let ruler: CGFloat = 20
    private static let sizes: ClosedRange<CGFloat> = 26...110

    private var size: CGFloat { min(max(cellSize * pinch, Self.sizes.lowerBound), Self.sizes.upperBound) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                board.padding(12)
            }
            .scrollIndicators(.hidden)
            // Start from A1 instead of centring a small grid (it would jump when the panel below appears).
            .defaultScrollAnchor(.topLeading)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        cellSize = min(max(cellSize * value.magnification, Self.sizes.lowerBound), Self.sizes.upperBound)
                    })
            .onAppear {
                guard let selected else { return }
                DispatchQueue.main.async { withAnimation { proxy.scrollTo(selected, anchor: .center) } }
            }
        }
    }

    private var board: some View {
        let width = CGFloat(room.columns) * size
        let height = CGFloat(room.rows) * size

        return ZStack(alignment: .topLeading) {
            ForEach(1...room.columns, id: \.self) { c in
                Text(MapItem.columnName(c))
                    .frame(width: size, height: ruler)
                    .placed(x: ruler + CGFloat(c - 1) * size, y: 0)
            }
            ForEach(1...room.rows, id: \.self) { r in
                Text("\(r)")
                    .frame(width: ruler, height: size)
                    .placed(x: 0, y: ruler + CGFloat(r - 1) * size)
            }

            GridLines(columns: room.columns, rows: room.rows)
                .stroke(Theme.surface3.opacity(editing ? 1 : 0.45), lineWidth: 1)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    onTapCell(Int(location.x / size) + 1, Int(location.y / size) + 1)
                }
                .placed(x: ruler, y: ruler)

            ForEach(room.items.filter { $0.kind == .zone }) { zone in
                let color = MapItem.zoneColors[zone.color % MapItem.zoneColors.count]
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(selected == zone.id ? 0.3 : 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    .frame(width: CGFloat(zone.width) * size - 2, height: CGFloat(zone.height) * size - 2)
                    .offset(offset(of: zone))
                    .allowsHitTesting(false)
                    .placed(x: x(zone) + 1, y: y(zone) + 1)

                // Only the label reacts to touches, so the cells inside the zone stay free for machines.
                Text(zone.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(color, in: Capsule())
                    .frame(maxWidth: CGFloat(zone.width) * size - 8, alignment: .leading)
                    .offset(offset(of: zone))
                    .onTapGesture { onTapItem(zone) }
                    .gesture(drag(zone), including: editing ? .all : .subviews)
                    .id(zone.id)
                    .placed(x: x(zone) + 5, y: y(zone) + 5)
            }

            ForEach(room.items.filter { $0.kind == .machine }) { machine in
                MachineTile(item: machine, size: size, selected: selected == machine.id, editing: editing)
                    .offset(offset(of: machine))
                    .zIndex(dragged == machine.id ? 1 : 0)
                    .onTapGesture { onTapItem(machine) }
                    .gesture(drag(machine), including: editing ? .all : .subviews)
                    .id(machine.id)
                    .placed(x: x(machine) + 2, y: y(machine) + 2)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.muted)
        .frame(width: ruler + width, height: ruler + height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.15), value: size)
    }

    private func x(_ item: MapItem) -> CGFloat { ruler + CGFloat(item.column - 1) * size }
    private func y(_ item: MapItem) -> CGFloat { ruler + CGFloat(item.row - 1) * size }

    private func offset(of item: MapItem) -> CGSize { dragged == item.id ? dragOffset : .zero }

    /// Follows the finger, then snaps to the nearest cell.
    private func drag(_ item: MapItem) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragged = item.id
                dragOffset = value.translation
            }
            .onEnded { value in
                let columns = Int((value.translation.width / size).rounded())
                let rows = Int((value.translation.height / size).rounded())
                dragged = nil
                dragOffset = .zero
                if columns != 0 || rows != 0 { onMove(item, item.column + columns, item.row + rows) }
            }
    }
}

/// A machine on the grid: its name, and its cell when there is room.
private struct MachineTile: View {
    let item: MapItem
    let size: CGFloat
    let selected: Bool
    let editing: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(item.name)
                .font(.system(size: min(max(size * 0.25, 9), 14), weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            if size >= 44 {
                Text(item.cell).font(.system(size: 9, weight: .bold)).opacity(0.6)
            }
        }
        .padding(3)
        .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
        .frame(width: CGFloat(item.width) * size - 4, height: CGFloat(item.height) * size - 4)
        .background(selected ? Theme.accent : Theme.surface3, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if item.photo != nil, size >= 40 {
                Image(systemName: "camera.fill").font(.system(size: 8)).padding(4).opacity(0.6)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(editing ? Theme.muted : .clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .shadow(color: .black.opacity(selected ? 0.5 : 0), radius: 8)
    }
}

private struct GridLines: Shape {
    let columns: Int
    let rows: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width / CGFloat(columns), h = rect.height / CGFloat(rows)
        for c in 0...columns {
            path.move(to: CGPoint(x: CGFloat(c) * w, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(c) * w, y: rect.height))
        }
        for r in 0...rows {
            path.move(to: CGPoint(x: 0, y: CGFloat(r) * h))
            path.addLine(to: CGPoint(x: rect.width, y: CGFloat(r) * h))
        }
        return path
    }
}

extension View {
    /// Puts the view at (x, y) inside a top-leading ZStack. Unlike `offset`, the view really
    /// moves there, so `ScrollViewReader.scrollTo` finds it.
    func placed(x: CGFloat, y: CGFloat) -> some View {
        alignmentGuide(.leading) { _ in -x }.alignmentGuide(.top) { _ in -y }
    }
}

extension MapItem {
    static let zoneColors: [Color] = [Theme.accent, Theme.warm, Color(hex: 0x5AC8FA), Color(hex: 0xFF5A5F),
                                      Color(hex: 0xB18CFF)]
}

#Preview {
    MapGrid(room: PreviewData.gym().map.rooms[0], editing: false, selected: nil,
            onTapCell: { _, _ in }, onTapItem: { _ in }, onMove: { _, _, _ in })
        .background(Theme.bg)
        .preferredColorScheme(.dark)
}
