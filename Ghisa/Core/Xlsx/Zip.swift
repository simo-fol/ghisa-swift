import Compression
import Foundation

/// Minimal zip reader/writer, enough for .xlsx files (stored and deflated entries, no zip64).
enum Zip {
    struct Entry {
        var name: String
        var data: Data
    }

    enum Failure: Error {
        case notAZip
        case unsupported(String)
        case corrupt(String)
    }

    // MARK: Reading

    static func read(_ archive: Data) throws -> [Entry] {
        let bytes = [UInt8](archive)
        guard let end = findEndOfCentralDirectory(bytes) else { throw Failure.notAZip }
        let count = Int(u16(bytes, end + 10))
        var offset = Int(u32(bytes, end + 16))
        var entries: [Entry] = []
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(bytes, offset) == 0x0201_4b50 else {
                throw Failure.corrupt("central directory")
            }
            let method = u16(bytes, offset + 10)
            let compressedSize = Int(u32(bytes, offset + 20))
            let size = Int(u32(bytes, offset + 24))
            let nameLength = Int(u16(bytes, offset + 28))
            let extraLength = Int(u16(bytes, offset + 30))
            let commentLength = Int(u16(bytes, offset + 32))
            let localOffset = Int(u32(bytes, offset + 42))
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            offset += 46 + nameLength + extraLength + commentLength

            guard localOffset + 30 <= bytes.count, u32(bytes, localOffset) == 0x0403_4b50 else {
                throw Failure.corrupt(name)
            }
            let start = localOffset + 30 + Int(u16(bytes, localOffset + 26)) + Int(u16(bytes, localOffset + 28))
            guard start + compressedSize <= bytes.count else { throw Failure.corrupt(name) }
            let raw = Array(bytes[start..<(start + compressedSize)])

            switch method {
            case 0: entries.append(Entry(name: name, data: Data(raw)))
            case 8: entries.append(Entry(name: name, data: try inflate(raw, size: size, name: name)))
            default: throw Failure.unsupported("\(name): method \(method)")
            }
        }
        return entries
    }

    static func findEndOfCentralDirectory(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        let lowest = max(0, bytes.count - 22 - 65_535)
        var i = bytes.count - 22
        while i >= lowest {
            if u32(bytes, i) == 0x0605_4b50 { return i }
            i -= 1
        }
        return nil
    }

    static func inflate(_ raw: [UInt8], size: Int, name: String) throws -> Data {
        if size == 0 { return Data() }
        var out = [UInt8](repeating: 0, count: size)
        let written = compression_decode_buffer(&out, size, raw, raw.count, nil, COMPRESSION_ZLIB)
        guard written == size else { throw Failure.corrupt(name) }
        return Data(out)
    }

    // MARK: Writing

    static func write(_ entries: [Entry]) -> Data {
        var out = [UInt8]()
        var central = [UInt8]()
        for entry in entries {
            let data = [UInt8](entry.data)
            let name = [UInt8](entry.name.utf8)
            let crc = crc32(data)
            let deflated = deflate(data)
            let method: UInt16 = deflated == nil ? 0 : 8
            let body = deflated ?? data
            let localOffset = out.count

            out += le32(0x0403_4b50)
            out += le16(20)                 // version needed
            out += le16(0x0800)             // UTF-8 names
            out += le16(method)
            out += le16(0) + le16(0x21)     // time, date (1980-01-01)
            out += le32(crc)
            out += le32(UInt32(body.count)) + le32(UInt32(data.count))
            out += le16(UInt16(name.count)) + le16(0)
            out += name
            out += body

            central += le32(0x0201_4b50)
            central += le16(20) + le16(20)
            central += le16(0x0800)
            central += le16(method)
            central += le16(0) + le16(0x21)
            central += le32(crc)
            central += le32(UInt32(body.count)) + le32(UInt32(data.count))
            central += le16(UInt16(name.count)) + le16(0) + le16(0)
            central += le16(0) + le16(0) + le32(0)
            central += le32(UInt32(localOffset))
            central += name
        }
        let centralOffset = out.count
        out += central
        out += le32(0x0605_4b50)
        out += le16(0) + le16(0)
        out += le16(UInt16(entries.count)) + le16(UInt16(entries.count))
        out += le32(UInt32(central.count)) + le32(UInt32(centralOffset))
        out += le16(0)
        return Data(out)
    }

    /// Raw deflate, or nil when it would not make the entry smaller.
    static func deflate(_ data: [UInt8]) -> [UInt8]? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + data.count / 8 + 1024
        var out = [UInt8](repeating: 0, count: capacity)
        let written = compression_encode_buffer(&out, capacity, data, data.count, nil, COMPRESSION_ZLIB)
        guard written > 0, written < data.count else { return nil }
        return Array(out[0..<written])
    }

    static let crcTable: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    static func u16(_ b: [UInt8], _ i: Int) -> UInt16 { UInt16(b[i]) | UInt16(b[i + 1]) << 8 }
    static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }
    static func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
    static func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)]
    }
}
