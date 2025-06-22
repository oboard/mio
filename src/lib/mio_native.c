#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <wchar.h>
#include <locale.h>
#include "cJSON.h"

#ifndef true
#define true 1
#endif

#ifndef false
#define false 0
#endif

// 定义枚举类型
typedef enum
{
    HTTP_GET,
    HTTP_POST,
    HTTP_PUT,
    HTTP_DELETE,
    HTTP_PATCH
} HttpMethod;

typedef enum
{
    CREDENTIALS_OMIT,
    CREDENTIALS_SAME_ORIGIN,
    CREDENTIALS_INCLUDE
} FetchCredentials;

typedef enum
{
    MODE_CORS,
    MODE_NO_CORS,
    MODE_SAME_ORIGIN,
    MODE_NAVIGATE
} FetchMode;

// 请求配置结构体
typedef struct
{
    const char *url;
    HttpMethod method;
    const char *body;
    struct curl_slist *headers;
    FetchCredentials credentials;
    FetchMode mode;
} FetchOptions;

// 回调函数，用于处理libcurl接收到的数据
size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp)
{
    size_t totalSize = size * nmemb;
    char **buffer = (char **)userp;
    size_t currentSize = *buffer ? strlen(*buffer) : 0;
    *buffer = realloc(*buffer, currentSize + totalSize + 1);
    if (*buffer == NULL)
    {
        printf("Memory allocation failed\n");
        return 0;
    }
    memcpy(*buffer + currentSize, contents, totalSize);
    (*buffer)[currentSize + totalSize] = '\0';
    return totalSize;
}

// 修改后的fetch函数
char *fetch(FetchOptions *options)
{
    CURL *curl;
    CURLcode res;
    char *response = NULL;
    struct curl_slist *headers = NULL;
    long http_code = 0;

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();

    if (curl)
    {
        // 设置URL
        curl_easy_setopt(curl, CURLOPT_URL, options->url);

        // 设置HTTP方法
        switch (options->method)
        {
        case HTTP_GET:
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
        if (options->body)
        {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, options->body);
        }

        // 设置默认请求头
        headers = curl_slist_append(headers, "User-Agent: MoonBit/1.0");
        headers = curl_slist_append(headers, "Accept: */*");

        // 添加用户自定义请求头
        if (options->headers)
        {
            headers = options->headers;
        }
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        // 设置凭证模式
        switch (options->credentials)
        {
        case CREDENTIALS_INCLUDE:
            curl_easy_setopt(curl, CURLOPT_COOKIEFILE, "");
            curl_easy_setopt(curl, CURLOPT_COOKIEJAR, "");
            break;
        case CREDENTIALS_SAME_ORIGIN:
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

        res = curl_easy_perform(curl);
        if (res != CURLE_OK)
        {
            fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
            if (response)
            {
                free(response);
                response = NULL;
            }
        }
        else
        {
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
            if (http_code >= 400)
            {
                fprintf(stderr, "HTTP request failed with status code %ld\n", http_code);
                if (response)
                {
                    free(response);
                    response = NULL;
                }
            }
        }

        if (headers && headers != options->headers)
        {
            curl_slist_free_all(headers);
        }
        curl_easy_cleanup(curl);
    }
    else
    {
        fprintf(stderr, "Failed to initialize CURL\n");
    }

    curl_global_cleanup();
    return response;
}

// 将 JSON 字符串转换为 FetchOptions 结构体
static FetchOptions parse_options(const char *json_str)
{
    FetchOptions options = {0};

    if (!json_str || strlen(json_str) == 0)
    {
        fprintf(stderr, "Error: Empty or invalid JSON input\n");
        return options;
    }

    cJSON *root = cJSON_Parse(json_str);
    if (!root)
    {
        fprintf(stderr, "Error: Failed to parse JSON\n");
        return options;
    }

    // 检查是否是数组格式
    if (!cJSON_IsArray(root))
    {
        fprintf(stderr, "Error: Input is not a JSON array\n");
        cJSON_Delete(root);
        return options;
    }

    // 获取 URL（第一个元素）
    cJSON *url = cJSON_GetArrayItem(root, 0);
    if (cJSON_IsString(url))
    {
        options.url = strdup(url->valuestring);
    }

    // 获取选项对象（第二个元素）
    cJSON *opts = cJSON_GetArrayItem(root, 1);
    if (cJSON_IsObject(opts))
    {
        // 解析方法
        cJSON *method = cJSON_GetObjectItem(opts, "method");
        if (cJSON_IsString(method))
        {
            if (strcmp(method->valuestring, "GET") == 0)
                options.method = HTTP_GET;
            else if (strcmp(method->valuestring, "POST") == 0)
                options.method = HTTP_POST;
            else if (strcmp(method->valuestring, "PUT") == 0)
                options.method = HTTP_PUT;
            else if (strcmp(method->valuestring, "DELETE") == 0)
                options.method = HTTP_DELETE;
            else if (strcmp(method->valuestring, "PATCH") == 0)
                options.method = HTTP_PATCH;
        }

        // 解析请求体
        cJSON *body = cJSON_GetObjectItem(opts, "body");
        if (body)
        {
            if (cJSON_IsString(body))
            {
                options.body = strdup(body->valuestring);
            }
            else
            {
                // 如果 body 是对象或数组，将其转换为字符串
                char *body_str = cJSON_Print(body);
                if (body_str)
                {
                    options.body = body_str;
                    // 自动添加 Content-Type 头
                    options.headers = curl_slist_append(options.headers, "Content-Type: application/json");
                }
            }
        }

        // 解析 headers
        cJSON *headers = cJSON_GetObjectItem(opts, "headers");
        if (cJSON_IsObject(headers))
        {
            cJSON *header;
            cJSON_ArrayForEach(header, headers)
            {
                if (cJSON_IsString(header))
                {
                    char header_line[1024];
                    snprintf(header_line, sizeof(header_line), "%s: %s", header->string, header->valuestring);
                    options.headers = curl_slist_append(options.headers, header_line);
                }
            }
        }

        // 解析凭证模式
        cJSON *credentials = cJSON_GetObjectItem(opts, "credentials");
        if (cJSON_IsString(credentials))
        {
            if (strcmp(credentials->valuestring, "omit") == 0)
                options.credentials = CREDENTIALS_OMIT;
            else if (strcmp(credentials->valuestring, "same-origin") == 0)
                options.credentials = CREDENTIALS_SAME_ORIGIN;
            else if (strcmp(credentials->valuestring, "include") == 0)
                options.credentials = CREDENTIALS_INCLUDE;
        }

        // 解析模式
        cJSON *mode = cJSON_GetObjectItem(opts, "mode");
        if (cJSON_IsString(mode))
        {
            if (strcmp(mode->valuestring, "cors") == 0)
                options.mode = MODE_CORS;
            else if (strcmp(mode->valuestring, "no-cors") == 0)
                options.mode = MODE_NO_CORS;
            else if (strcmp(mode->valuestring, "same-origin") == 0)
                options.mode = MODE_SAME_ORIGIN;
            else if (strcmp(mode->valuestring, "navigate") == 0)
                options.mode = MODE_NAVIGATE;
        }
    }

    cJSON_Delete(root);
    return options;
}

// 清理 FetchOptions 结构体
static void cleanup_options(FetchOptions *options)
{
    if (options->url)
        free((void *)options->url);
    if (options->body)
        free((void *)options->body);
    if (options->headers)
        curl_slist_free_all(options->headers);
}

// MoonBit 接口函数
char *request_buffer_internal(const char *args, const char *callback)
{
    if (!args)
    {
        fprintf(stderr, "Error: Empty or invalid input\n");
        return NULL;
    }

    FetchOptions options = parse_options(args);
    if (!options.url)
    {
        fprintf(stderr, "Error: Failed to parse URL from args\n");
        return NULL;
    }

    char *response = fetch(&options);
    cleanup_options(&options);

    if (!response)
    {
        return NULL;
    }

    // 构造响应 JSON
    cJSON *json_response = cJSON_CreateObject();
    cJSON_AddObjectToObject(json_response, "headers");
    cJSON_AddNumberToObject(json_response, "status", 200);
    cJSON_AddStringToObject(json_response, "statusText", "OK");
    cJSON_AddBoolToObject(json_response, "ok", 1);

    // 尝试解析响应为 JSON
    cJSON *response_data = cJSON_Parse(response);
    if (response_data)
    {
        cJSON_AddItemToObject(json_response, "data", response_data);
    }
    else
    {
        cJSON_AddStringToObject(json_response, "data", response);
    }

    char *result = cJSON_Print(json_response);
    cJSON_Delete(json_response);
    free(response);

    return result;
}

char *request_text_internal(const char *args, const char *callback)
{
    if (!args)
    {
        fprintf(stderr, "Error: Empty or invalid input\n");
        return NULL;
    }

    FetchOptions options = parse_options(args);
    if (!options.url)
    {
        fprintf(stderr, "Error: Failed to parse URL from args\n");
        return NULL;
    }

    char *response = fetch(&options);
    cleanup_options(&options);

    if (!response)
    {
        return NULL;
    }

    // 构造响应 JSON
    cJSON *json_response = cJSON_CreateObject();
    cJSON_AddObjectToObject(json_response, "headers");
    cJSON_AddNumberToObject(json_response, "status", 200);
    cJSON_AddStringToObject(json_response, "statusText", "OK");
    cJSON_AddBoolToObject(json_response, "ok", 1);
    cJSON_AddStringToObject(json_response, "data", response);

    char *result = cJSON_Print(json_response);
    cJSON_Delete(json_response);
    free(response);

    return result;
}