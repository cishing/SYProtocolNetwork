import UIKit

struct UserModel {
    
    var name: String
}

enum SYResult<R> {
    
    case success(R)
    
    case failure(Error)
}

// 解析
protocol SYParsable {
    
    static func parse(data: Data) -> SYResult<Self>
}

extension SYParsable where Self: Decodable {
    
    static func parse(data: Data) -> SYResult<Self> {
        
        let decoder = JSONDecoder()
        
        do {
            let model = try decoder.decode(self, from: data)
            
            return .success(model)
        } catch  {
            
            return .failure(error)
        }
    }
}

extension UserModel: SYParsable, Decodable {}

typealias ArrayDecodable = SYParsable & Decodable

extension Array: SYParsable where Element: ArrayDecodable {}

// 请求
enum HTTPMethod: String {
    
    case get = "GET"
    case post = "POST"
}

typealias HTTPHeaders = [String: String]

protocol Request {
    
    var url: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: Any]? { get }
    var headers: HTTPHeaders? { get }
    var httpBody: Data? { get }
    
    associatedtype Response: SYParsable
}

struct NormalRequest<P: SYParsable>: Request {
    
    var url: String
    
    var method: HTTPMethod
    
    var parameters: [String : Any]?
    
    var headers: HTTPHeaders?
    
    var httpBody: Data?
    
    typealias Response = P
    
    init(_ responseType: P.Type, urlString: String,
         method: HTTPMethod = .get,
         parameters: [String: Any]? = nil,
         headers: HTTPHeaders? = nil,
         httpBody: Data? = nil) {
        
        self.url = urlString
        self.method = method
        self.parameters = parameters
        self.headers = headers
        self.httpBody = httpBody
    }
}

let request = NormalRequest(UserModel.self, urlString: "")

// 客户端
typealias Handler<H> = (SYResult<H>) -> Void

protocol Client {
    
    func send<R: Request>(request: R, completionHandler: @escaping Handler<R.Response>)
}

struct URLSessionClient: Client {
    
    func send<R: Request>(request: R, completionHandler: @escaping (SYResult<R.Response>) -> Void) {
        
        var urlString = request.url
        if let param = request.parameters {
            var i = 0
            param.forEach {
                urlString += i == 0 ? "?\($0.key)=\($0.value)" : "&\($0.key)=\($0.value)"
                i += 1
            }
        }
        guard let url = URL(string: urlString) else {
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.httpBody
        req.allHTTPHeaderFields = request.headers
        
        URLSession.shared.dataTask(with: req) { (data, respose, error) in
            if let data = data {
                // 使用parse方法反序列化
                let result = R.Response.parse(data: data)
                
                switch result {
                    
                case .success(let model):
                    
                    completionHandler(.success(model))
                    
                case .failure(let error):
                    
                    completionHandler(.failure(error))
                }
            } else {
                
                completionHandler(.failure(error!))
            }
        }
    }
}
