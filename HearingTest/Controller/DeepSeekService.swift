import Foundation

class DeepSeekService {
    // MARK: - Properties
    private let apiKey = "sk-b2755115c9c941b1af3cc1697dfbf4c9"
    private let baseURL = "https://api.deepseek.com/v1"
    
    // MARK: - Error Types
    enum APIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case rateLimitExceeded
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的 URL"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "无效的响应"
            case .decodingError(let error):
                return "解码错误: \(error.localizedDescription)"
            case .rateLimitExceeded:
                return "请求频率超限"
            case .serverError(let message):
                return "服务器错误: \(message)"
            }
        }
    }
    
    // MARK: - Response Models
    struct ChatResponse: Codable {
        let id: String
        let choices: [Choice]
        let usage: Usage
        
        struct Choice: Codable {
            let message: Message
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        
        struct Message: Codable {
            let role: String
            let content: String
        }
        
        struct Usage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    // MARK: - Public Methods
    func generateResponse(prompt: String) async throws -> String {
        let endpoint = "\(baseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                [
                    "role": "system",
                    "content": "你是一位专业的听力医生，请根据听力测试结果给出专业的分析和建议。请直接给出分析内容，不要使用markdown格式。"
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                let result = try decoder.decode(ChatResponse.self, from: data)
                let content = result.choices.first?.message.content ?? "无分析结果"
                return removeMarkdown(from: content)
            case 429:
                throw APIError.rateLimitExceeded
            default:
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw APIError.serverError(message)
                }
                throw APIError.invalidResponse
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    private func removeMarkdown(from text: String) -> String {
        var result = text
        
        // 移除标题标记 (# ## ### 等)
        result = result.replacingOccurrences(of: "#{1,6}\\s", with: "", options: .regularExpression)
        
        // 移除加粗标记 (**)
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        
        // 移除斜体标记 (*)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        
        // 移除列表标记 (- * +)
        result = result.replacingOccurrences(of: "^[\\-\\*\\+]\\s+", with: "", options: .regularExpression)
        
        // 移除代码块标记 (```)
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        
        // 移除行内代码标记 (`)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        
        // 移除链接标记 ([text](url))
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
        
        // 移除多余的空行
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 