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
                    "content": "你是一位专业的听力医生，请根据听力测试结果给出专业的分析和建议。"
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
                return result.choices.first?.message.content ?? "无分析结果"
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
    
    // MARK: - Helper Methods
    private func formatHearingAnalysis(results: [HearingResult]) -> String {
        var prompt = "请分析以下听力测试结果：\n\n"
        
        // 添加频率和阈值数据
        for result in results {
            prompt += "频率 \(result.frequency)Hz: \(result.threshold)dB\n"
        }
        
        // 计算平均听力损失
        let average = results.map { $0.threshold }.reduce(0, +) / Float(results.count)
        prompt += "\n平均听力损失：\(String(format: "%.1f", average))dB\n"
        
        // 添加听力等级
        let severity = HearingResult(frequency: 0, threshold: average).getSeverityLevel()
        prompt += "听力等级：\(severity.rawValue)\n\n"
        
        prompt += "请提���：\n1. 听力状况分析\n2. 可能的原因\n3. 建议和预防措施"
        
        return prompt
    }
} 