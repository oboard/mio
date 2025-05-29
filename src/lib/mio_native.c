#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>

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
    *buffer = realloc(*buffer, totalSize + 1); // 为字符串末尾的'\0'预留空间
    if (*buffer == NULL) {
        printf("Memory allocation failed\n");
        return 0; // 出错时返回0
    }
    memcpy(*buffer, contents, totalSize);
    (*buffer)[totalSize] = '\0'; // 确保字符串以'\0'结尾
    return totalSize;
}

// 修改后的fetch函数
char* fetch(FetchOptions* options) {
    CURL* curl;
    CURLcode res;
    char* response = NULL;

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

        // 设置请求头
        if (options->headers) {
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, options->headers);
        }

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

        res = curl_easy_perform(curl);
        if(res != CURLE_OK) {
            fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
        }

        curl_easy_cleanup(curl);
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
    char* start = strchr(json, '[');
    if (!start) return NULL;
    start++;
    
    int current_index = 0;
    while (*start && current_index < index) {
        if (*start == '[') {
            // 跳过嵌套数组
            int depth = 1;
            start++;
            while (*start && depth > 0) {
                if (*start == '[') depth++;
                if (*start == ']') depth--;
                start++;
            }
        } else if (*start == ',') {
            current_index++;
        }
        start++;
    }
    
    if (!*start) return NULL;
    
    // 找到元素的结束位置
    char* end = start;
    int depth = 0;
    while (*end && (depth > 0 || (*end != ',' && *end != ']'))) {
        if (*end == '[') depth++;
        if (*end == ']') depth--;
        end++;
    }
    
    size_t len = end - start;
    char* value = malloc(len + 1);
    strncpy(value, start, len);
    value[len] = '\0';
    
    return value;
}

// 将 JSON 字符串转换为 FetchOptions 结构体
static FetchOptions parse_options(const char* json_str) {
    FetchOptions options = {0};
    
    // 获取数组中的 URL 和选项
    char* url_json = get_array_element(json_str, 0);
    char* options_json = get_array_element(json_str, 1);
    
    if (url_json) {
        options.url = url_json;
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
char* request_buffer_internal(const char* args, void* callback) {
    FetchOptions options = parse_options(args);
    char* response = fetch(&options);
    cleanup_options(&options);
    
    if (!response) {
        return NULL;
    }
    
    // 构造响应 JSON
    char* json_response = malloc(strlen(response) + 100); // 预留足够空间
    sprintf(json_response, 
        "{\"headers\":{},\"status\":200,\"statusText\":\"OK\",\"ok\":true,\"data\":%s}",
        response);
    
    free(response);
    return json_response;
}

char* request_text_internal(const char* args, void* callback) {
    return request_buffer_internal(args, callback);
}