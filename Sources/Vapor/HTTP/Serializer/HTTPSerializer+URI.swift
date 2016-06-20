extension URI {
    public mutating func append(query appendQuery: [String: String]) {
        guard !appendQuery.isEmpty else { return }

        var new = ""
        if let existing = query where !existing.isEmpty {
            new += existing
            new += "&"
        }
        new += appendQuery.map { key, val in "\(key)=\(val)" } .joined(separator: "&")
        query = new
    }
}
