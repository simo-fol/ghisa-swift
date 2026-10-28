import Foundation

/// The loaded workbook: parsed protocols plus the package used to write results back.
final class LogBook {
    private let package: XlsxPackage
    let protocols: [TrainingProtocol]

    private init(package: XlsxPackage) {
        self.package = package
        protocols = WorkbookParser.parse(package)
    }

    static func load(_ xlsx: Data) throws -> LogBook { LogBook(package: try XlsxPackage.load(xlsx)) }

    /// Writes the load/reps of one exercise into the given week of the sheet.
    func record(_ proto: TrainingProtocol, _ exercise: ExerciseRow, week: Int, load: String, reps: String) {
        guard let sheet = package.sheets.first(where: { $0.name == proto.sheetName }) else { return }
        let cell = exercise.weeks[week]
        sheet.setText(cell.loadRef, load)
        sheet.setText(cell.repsRef, reps)
        cell.load = load
        cell.reps = reps
    }

    func save() -> Data { package.save() }
}
