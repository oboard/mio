#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <wchar.h>
#include <locale.h>

// 定义枚举类型
typedef enum {
    HTTP_GET,
    HTTP_POST,
    HTTP_PUT,
    HTTP_DELETE,
    HTTP_PATCH
} HttpMethod;

typedef enum {
    CREDENTIALS_OMIT,
    CREDENTIALS_SAME_ORIGIN,
    CREDENTIALS_INCLUDE
} FetchCredentials;

typedef enum {
    MODE_CORS,
    MODE_NO_CORS,
    MODE_SAME_ORIGIN,
    MODE_NAVIGATE
} FetchMode;

// 请求配置结构体
typedef struct {
    const char* url;
    HttpMethod method;
    const char* body;
    struct curl_slist* headers;
    FetchCredentials credentials;
    FetchMode mode;
} FetchOptions;

// 回调函数，用于处理libcurl接收到的数据
size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t totalSize = size * nmemb;
    char** buffer = (char**)userp;
    size_t currentSize = *buffer ? strlen(*buffer) : 0;
    *buffer = realloc(*buffer, currentSize + totalSize + 1); // 为字符串末尾的'\0'预留空间
    if (*buffer == NULL) {
        printf("Memory allocation failed\n");
        return 0; // 出错时返回0
    }
    memcpy(*buffer + currentSize, contents, totalSize);
    (*buffer)[currentSize + totalSize] = '\0'; // 确保字符串以'\0'结尾
    return totalSize;
}

// 修改后的fetch函数
char* fetch(FetchOptions* options) {
    CURL* curl;
    CURLcode res;
    char* response = NULL;
    struct curl_slist* headers = NULL;
    long http_code = 0;

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();

    if(curl) {
        // 设置URL
        curl_easy_setopt(curl, CURLOPT_URL, options->url);
        
        // 设置HTTP方法
        switch(options->method) {
            case HTTP_GET:
                // GET 是默认方法，不需要特殊设置
                break;
            case HTTP_POST:
                curl_easy_setopt(curl, CURLOPT_POST, 1L);
                break;
            case HTTP_PUT:
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
                break;
            case HTTP_DELETE:
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
                break;
            case HTTP_PATCH:
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PATCH");
                break;
            default:
                fprintf(stderr, "Unknown HTTP method\n");
                break;
        }

        // 设置请求体
        if (options->body) {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, options->body);
        }

        // 设置默认请求头
        headers = curl_slist_append(headers, "User-Agent: MoonBit/1.0");
        headers = curl_slist_append(headers, "Accept: */*");
        
        // 添加用户自定义请求头
        if (options->headers) {
            headers = options->headers;
        }
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        // 设置凭证模式
        switch(options->credentials) {
            case CREDENTIALS_INCLUDE:
                curl_easy_setopt(curl, CURLOPT_COOKIEFILE, "");
                curl_easy_setopt(curl, CURLOPT_COOKIEJAR, "");
                break;
            case CREDENTIALS_SAME_ORIGIN:
                // 使用与来源相同的凭证
                curl_easy_setopt(curl, CURLOPT_COOKIEFILE, "");
                curl_easy_setopt(curl, CURLOPT_COOKIEJAR, "");
                break;
            case CREDENTIALS_OMIT:
                curl_easy_setopt(curl, CURLOPT_COOKIEFILE, NULL);
                curl_easy_setopt(curl, CURLOPT_COOKIEJAR, NULL);
                break;
            default:
                fprintf(stderr, "Unknown credentials mode\n");
                break;
        }

        // 设置回调函数
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

        // 设置 SSL 选项
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);

        // 设置超时
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);

        // 启用重定向
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5L);

        // 启用详细输出
        // curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

        res = curl_easy_perform(curl);
        if(res != CURLE_OK) {
            fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
            if (response) {
                free(response);
                response = NULL;
            }
        } else {
            // 获取 HTTP 状态码
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
            // fprintf(stderr, "HTTP Status Code: %ld\n", http_code);
            
            if (http_code >= 400) {
                fprintf(stderr, "HTTP request failed with status code %ld\n", http_code);
                if (response) {
                    // fprintf(stderr, "Response body: %s\n", response);
                    free(response);
                    response = NULL;
                }
            } else {
                // fprintf(stderr, "Request successful, response length: %zu\n", response ? strlen(response) : 0);
            }
        }

        // 清理
        if (headers && headers != options->headers) {
            curl_slist_free_all(headers);
        }
        curl_easy_cleanup(curl);
    } else {
        fprintf(stderr, "Failed to initialize CURL\n");
    }

    curl_global_cleanup();
    return response;
}

// // 示例用法
// int main() {
//     struct curl_slist* headers = NULL;
//     headers = curl_slist_append(headers, "Content-Type: application/json");
    
//     FetchOptions options = {
//         .url = "https://api.github.com",
//         .method = HTTP_GET,
//         .body = NULL,
//         .headers = headers,
//         .credentials = CREDENTIALS_SAME_ORIGIN,
//         .mode = MODE_CORS
//     };

//     char* response = fetch(&options);

//     if (response) {
//         printf("Response:\n%s\n", response);
//         free(response);
//     }

//     curl_slist_free_all(headers);
//     return 0;
// }

// 简单的字符串解析函数
static char* get_value(const char* json, const char* key) {
    char* key_pattern = malloc(strlen(key) + 4);
    sprintf(key_pattern, "\"%s\":", key);
    
    char* start = strstr(json, key_pattern);
    if (!start) {
        free(key_pattern);
        return NULL;
    }
    
    start += strlen(key_pattern);
    while (*start && (*start == ' ' || *start == '\t')) start++;
    
    if (*start != '"') {
        free(key_pattern);
        return NULL;
    }
    
    start++;
    char* end = strchr(start, '"');
    if (!end) {
        free(key_pattern);
        return NULL;
    }
    
    size_t len = end - start;
    char* value = malloc(len + 1);
    strncpy(value, start, len);
    value[len] = '\0';
    
    free(key_pattern);
    return value;
}

// 从数组中获取元素
static char* get_array_element(const char* json, int index) {
    if (!json || json[0] != '[') {
        // fprintf(stderr, "Debug - Invalid array format: %s\n", json);
        return NULL;
    }
    
    char* start = json + 1;  // 跳过开始的 '['
    int current_index = 0;
    int depth = 0;
    
    while (*start && current_index < index) {
        if (*start == '[') {
            depth++;
        } else if (*start == ']') {
            if (depth == 0) {
                // fprintf(stderr, "Debug - Array ended before reaching index %d\n", index);
                return NULL;
            }
            depth--;
        } else if (*start == ',' && depth == 0) {
            current_index++;
        }
        start++;
    }
    
    if (!*start || *start == ']') {
        // fprintf(stderr, "Debug - End of array reached at index %d\n", current_index);
        return NULL;
    }
    
    // 找到元素的结束位置
    char* end = start;
    depth = 0;
    while (*end && (depth > 0 || (*end != ',' && *end != ']'))) {
        if (*end == '[') depth++;
        if (*end == ']') depth--;
        end++;
    }
    
    size_t len = end - start;
    char* value = malloc(len + 1);
    strncpy(value, start, len);
    value[len] = '\0';
    
    // fprintf(stderr, "Debug - Extracted array element: %s\n", value);
    return value;
}

// 将 JSON 字符串转换为 FetchOptions 结构体
static FetchOptions parse_options(const char* json_str) {
    FetchOptions options = {0};
    
    // 检查输入是否为空或无效
    if (!json_str || strlen(json_str) == 0) {
        fprintf(stderr, "Error: Empty or invalid JSON input\n");
        return options;
    }
    
    // fprintf(stderr, "Debug - Raw input: %s\n", json_str);
    
    // 解析 JSON 字符串
    char* url = NULL;
    char* options_json = NULL;
    
    // 跳过开头的空白字符
    while (*json_str && (*json_str == ' ' || *json_str == '\t' || *json_str == '\n')) {
        json_str++;
    }
    
    // 检查是否是数组格式
    if (*json_str == '[') {
        json_str++;  // 跳过 '['
        
        // 解析 URL
        while (*json_str && (*json_str == ' ' || *json_str == '\t' || *json_str == '\n')) {
            json_str++;
        }
        
        if (*json_str == '"') {
            json_str++;  // 跳过 '"'
            char* end = strchr(json_str, '"');
            if (end) {
                size_t len = end - json_str;
                url = malloc(len + 1);
                strncpy(url, json_str, len);
                url[len] = '\0';
                json_str = end + 1;
            }
        }
        
        // 跳过到选项部分
        while (*json_str && *json_str != ',') {
            json_str++;
        }
        if (*json_str == ',') {
            json_str++;  // 跳过 ','
            // 找到选项对象的结束位置
            char* end = json_str;
            int depth = 0;
            while (*end && (depth > 0 || (*end != ']'))) {
                if (*end == '{') depth++;
                if (*end == '}') depth--;
                end++;
            }
            if (end > json_str) {
                size_t len = end - json_str;
                options_json = malloc(len + 1);
                strncpy(options_json, json_str, len);
                options_json[len] = '\0';
            }
        }
    } else {
        // 如果不是数组格式，直接使用整个字符串作为 URL
        url = strdup(json_str);
    }
    
    // fprintf(stderr, "Debug - Parsed URL: %s\n", url ? url : "NULL");
    // fprintf(stderr, "Debug - Parsed options: %s\n", options_json ? options_json : "NULL");
    
    if (url) {
        options.url = url;
    }
    
    if (options_json) {
        // 解析方法
        char* method = get_value(options_json, "method");
        if (method) {
            if (strcmp(method, "GET") == 0) options.method = HTTP_GET;
            else if (strcmp(method, "POST") == 0) options.method = HTTP_POST;
            else if (strcmp(method, "PUT") == 0) options.method = HTTP_PUT;
            else if (strcmp(method, "DELETE") == 0) options.method = HTTP_DELETE;
            else if (strcmp(method, "PATCH") == 0) options.method = HTTP_PATCH;
            free(method);
        }
        
        // 解析请求体
        char* body = get_value(options_json, "body");
        if (body) {
            options.body = body;
        }
        
        // 解析凭证模式
        char* credentials = get_value(options_json, "credentials");
        if (credentials) {
            if (strcmp(credentials, "omit") == 0) options.credentials = CREDENTIALS_OMIT;
            else if (strcmp(credentials, "same-origin") == 0) options.credentials = CREDENTIALS_SAME_ORIGIN;
            else if (strcmp(credentials, "include") == 0) options.credentials = CREDENTIALS_INCLUDE;
            free(credentials);
        }
        
        // 解析模式
        char* mode = get_value(options_json, "mode");
        if (mode) {
            if (strcmp(mode, "cors") == 0) options.mode = MODE_CORS;
            else if (strcmp(mode, "no-cors") == 0) options.mode = MODE_NO_CORS;
            else if (strcmp(mode, "same-origin") == 0) options.mode = MODE_SAME_ORIGIN;
            else if (strcmp(mode, "navigate") == 0) options.mode = MODE_NAVIGATE;
            free(mode);
        }
        
        free(options_json);
    }
    
    return options;
}

// 清理 FetchOptions 结构体
static void cleanup_options(FetchOptions* options) {
    if (options->url) free((void*)options->url);
    if (options->body) free((void*)options->body);
    if (options->headers) curl_slist_free_all(options->headers);
}

// MoonBit 接口函数
char* request_buffer_internal(const char* args, const char* callback) {
    // fprintf(stderr, "Debug - C received args: %s\n", args);
    
    // 检查输入是否为空或无效
    if (!args) {
        fprintf(stderr, "Error: Empty or invalid input\n");
        return NULL;
    }
    
    // 检查是否是数组格式
    if (args[0] != '[') {
        fprintf(stderr, "Error: Input is not a JSON array\n");
        return NULL;
    }
    
    // 复制完整的 JSON 字符串
    char* json_str = strdup(args);
    if (!json_str) {
        fprintf(stderr, "Error: Failed to allocate memory\n");
        return NULL;
    }
    
    // fprintf(stderr, "Debug - Complete JSON: %s\n", json_str);
    
    FetchOptions options = parse_options(json_str);
    free(json_str);
    
    if (!options.url) {
        fprintf(stderr, "Error: Failed to parse URL from args\n");
        return NULL;
    }
    
    char* response = fetch(&options);
    cleanup_options(&options);
    
    if (!response) {
        fprintf(stderr, "Error: Failed to fetch response\n");
        return NULL;
    }
    
    // 构造响应 JSON
    char* json_response = malloc(strlen(response) + 100); // 预留足够空间
    if (!json_response) {
        free(response);
        fprintf(stderr, "Error: Failed to allocate memory for response\n");
        return NULL;
    }
    
    sprintf(json_response, 
        "{\"headers\":{},\"status\":200,\"statusText\":\"OK\",\"ok\":true,\"data\":%s}",
        response);
    
    free(response);
    return json_response;
}

char* request_text_internal(const char* args, const char* callback) {
    // fprintf(stderr, "Debug - C received args: %s\n", args);
    
    // 检查输入是否为空或无效
    if (!args) {
        fprintf(stderr, "Error: Empty or invalid input\n");
        return NULL;
    }
    
    // 检查是否是数组格式
    if (args[0] != '[') {
        fprintf(stderr, "Error: Input is not a JSON array\n");
        return NULL;
    }
    
    // 复制完整的 JSON 字符串
    char* json_str = strdup(args);
    if (!json_str) {
        fprintf(stderr, "Error: Failed to allocate memory\n");
        return NULL;
    }
    
    // fprintf(stderr, "Debug - Complete JSON: %s\n", json_str);
    
    FetchOptions options = parse_options(json_str);
    free(json_str);
    
    if (!options.url) {
        fprintf(stderr, "Error: Failed to parse URL from args\n");
        return NULL;
    }
    
    char* response = fetch(&options);
    cleanup_options(&options);
    
    if (!response) {
        return NULL;
    }
    
    // 构造响应 JSON
    char* json_response = malloc(strlen(response) + 100); // 预留足够空间
    if (!json_response) {
        free(response);
        fprintf(stderr, "Error: Failed to allocate memory for response\n");
        return NULL;
    }
    
    // 转义响应中的特殊字符
    char* escaped_response = malloc(strlen(response) * 2 + 1);
    if (!escaped_response) {
        free(response);
        free(json_response);
        fprintf(stderr, "Error: Failed to allocate memory for escaped response\n");
        return NULL;
    }
    
    size_t j = 0;
    for (size_t i = 0; response[i]; i++) {
        switch (response[i]) {
            case '"':
                escaped_response[j++] = '\\';
                escaped_response[j++] = '"';
                break;
            case '\\':
                escaped_response[j++] = '\\';
                escaped_response[j++] = '\\';
                break;
            case '\n':
                escaped_response[j++] = '\\';
                escaped_response[j++] = 'n';
                break;
            case '\r':
                escaped_response[j++] = '\\';
                escaped_response[j++] = 'r';
                break;
            case '\t':
                escaped_response[j++] = '\\';
                escaped_response[j++] = 't';
                break;
            default:
                escaped_response[j++] = response[i];
        }
    }
    escaped_response[j] = '\0';
    
    sprintf(json_response, 
        "{\"headers\":{},\"status\":200,\"statusText\":\"OK\",\"ok\":true,\"data\":\"%s\"}",
        escaped_response);
    
    free(response);
    free(escaped_response);
    return json_response;
}