import Foundation

// MARK: - Web Search Service

@Observable
class WebSearchService {
    var isSearching = false
    var lastResults: [WebSearchResult] = []
    var lastError: String?
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "OllamaBot/1.0 (macOS)"
        ]
        session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Search the web using DuckDuckGo HTML (no API key needed)
    func search(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        isSearching = true
        lastError = nil
        
        defer { isSearching = false }
        
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)")
        else {
            throw WebSearchError.invalidQuery
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw WebSearchError.requestFailed
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw WebSearchError.invalidResponse
            }
            
            let results = parseResults(from: html, maxResults: maxResults)
            lastResults = results
            return results
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Fetch content from a URL
    func fetchContent(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw WebSearchError.invalidQuery
        }
        
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.invalidResponse
        }
        
        // Extract text content from HTML (basic)
        return extractText(from: html)
    }
    
    // MARK: - Private Helpers
    
    private func parseResults(from html: String, maxResults: Int) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        
        // Parse DuckDuckGo HTML results
        // Look for result links in the format:
        // <a rel="nofollow" class="result__a" href="...">Title</a>
        // <a class="result__snippet" href="...">Snippet</a>
        
        // Simple regex-based extraction
        let linkPattern = #"<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a[^>]*class="result__snippet"[^>]*>([^<]*)</a>"#
        
        let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [])
        let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: [])
        
        let range = NSRange(html.startIndex..., in: html)
        
        let linkMatches = linkRegex?.matches(in: html, options: [], range: range) ?? []
        let snippetMatches = snippetRegex?.matches(in: html, options: [], range: range) ?? []
        
        for (index, match) in linkMatches.prefix(maxResults).enumerated() {
            if let urlRange = Range(match.range(at: 1), in: html),
               let titleRange = Range(match.range(at: 2), in: html) {
                
                var url = String(html[urlRange])
                let title = String(html[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                
                // DuckDuckGo wraps URLs, extract actual URL
                if url.contains("uddg=") {
                    if let actualUrl = url.components(separatedBy: "uddg=").last?
                        .components(separatedBy: "&").first?
                        .removingPercentEncoding {
                        url = actualUrl
                    }
                }
                
                var snippet = ""
                if index < snippetMatches.count,
                   let snippetRange = Range(snippetMatches[index].range(at: 1), in: html) {
                    snippet = String(html[snippetRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                }
                
                guard !url.isEmpty, url.hasPrefix("http") else { continue }
                
                results.append(WebSearchResult(
                    title: title.isEmpty ? "Untitled" : title,
                    url: url,
                    snippet: snippet
                ))
            }
        }
        
        return results
    }
    
    private func extractText(from html: String) -> String {
        var text = html
        
        // Remove script and style tags
        text = text.replacingOccurrences(
            of: #"<script[^>]*>[\s\S]*?</script>"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"<style[^>]*>[\s\S]*?</style>"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove HTML tags
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        
        // Decode HTML entities
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Clean up whitespace
        text = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Models

struct WebSearchResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
    
    enum CodingKeys: String, CodingKey {
        case title, url, snippet
    }
}

enum WebSearchError: Error, LocalizedError {
    case invalidQuery
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .requestFailed: return "Search request failed"
        case .invalidResponse: return "Invalid response from search"
        }
    }
}

// MARK: - Web Search View

import SwiftUI

struct WebSearchResultsView: View {
    let results: [WebSearchResult]
    let onSelect: (WebSearchResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(results) { result in
                WebSearchResultCard(result: result)
                    .onTapGesture { onSelect(result) }
            }
        }
    }
}

struct WebSearchResultCard: View {
    let result: WebSearchResult
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(result.title)
                .font(DS.Typography.callout.weight(.medium))
                .foregroundStyle(DS.Colors.accent)
                .lineLimit(1)
            
            Text(result.url)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .lineLimit(1)
            
            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? DS.Colors.surface : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .onHover { isHovered = $0 }
    }
}
