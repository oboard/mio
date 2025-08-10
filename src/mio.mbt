///|
pub fn run(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
pub suberror IOError derive(Show)

///|
pub suberror NetworkError derive(Show)

///|
pub suberror StreamError derive(Show)

///|
pub suberror UnimplementedError derive(Show)

///|
pub suberror ExecError derive(Show)

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(ToJson(style="flat"), Show, Eq)

///|
pub(all) enum FetchMode {
  CORS
  NoCORS
  SameOrigin
  Navigate
} derive(ToJson(style="flat"), Show, Eq)

///|
pub struct HttpResponse {
  mut statusCode : Int
  mut headers : Map[String, String]
  data : Bytes
} derive(Show, Eq)

///|
pub struct SSEEvent {
  mut event_type : String?
  mut data : String
  mut id : String?
  mut retry : Int?
} derive(Show, Eq)

///|
pub fn HttpResponse::json(self : HttpResponse) -> Json raise @json.ParseError {
  @json.parse(self.text())
}

///|
pub fn HttpResponse::unwrap_json(self : HttpResponse) -> Json {
  (try? self.json()).or(Json::null())
}

///|
pub fn HttpResponse::text(self : HttpResponse) -> String {
  @buffer.from_bytes(self.data).to_string()
}

///|
pub fn SSEEvent::parse(data : String) -> Array[SSEEvent] {
  let events = []
  let lines = data.split("\n")
  let mut current_event = SSEEvent::{
    event_type: None,
    data: "",
    id: None,
    retry: None,
  }
  let mut has_data = false
  for line in lines {
    let trimmed = line.to_string()
    if trimmed == "" {
      if has_data {
        events.push(current_event)
        current_event = SSEEvent::{
          event_type: None,
          data: "",
          id: None,
          retry: None,
        }
        has_data = false
      }
    } else if trimmed.strip_prefix(":") != None {
      // Comment line, ignore
      continue
    } else if trimmed.find(":") is Some(colon_pos) {
      let field = trimmed.substring(start=0, end=colon_pos)
      let value = if colon_pos + 1 < trimmed.length() {
        trimmed.substring(start=colon_pos + 1, end=trimmed.length())
      } else {
        ""
      }
      match field {
        "event" => current_event.event_type = Some(value)
        "data" => {
          if current_event.data != "" {
            current_event.data = current_event.data + "\n" + value
          } else {
            current_event.data = value
          }
          has_data = true
        }
        "id" => current_event.id = Some(value)
        "retry" =>
          try {
            current_event.retry = Some(@strconv.parse_int(value))
          } catch {
            _ => continue
          }
        _ => continue
      }
    } else {
      // Field without colon, treat as data
      if current_event.data != "" {
        current_event.data = current_event.data + "\n" + trimmed
      } else {
        current_event.data = trimmed
      }
      has_data = true
    }
  }
  if has_data {
    events.push(current_event)
  }
  events
}

///|
pub(all) enum HttpMethod {
  GET
  POST
  PUT
  DELETE
  PATCH
  OPTIONS
  HEAD
  CONNECT
  TRACE
} derive(ToJson(style="legacy"), Show, Eq)

///|
pub(all) struct HttpRequest {
  request_method : HttpMethod
  url : String?
  path : String
  query : String?
  body : Json?
} derive(ToJson, Show, Eq)

///|
pub fn listen(_port : Int) -> Unit raise Error {
  fail("Invalid backend")
}

///|
pub fn handle(_reqMethod : String, _mapping : String) -> Unit {

}

///|
pub fn writeHead(
  self : HttpResponse,
  statusCode : Int,
  headers : Map[String, String],
) -> Unit {
  // (binding.send)("http.writeHead", [Number(self.id), statusCode, headers])
  self.statusCode = statusCode
  self.headers = headers
}

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(url, http_method=HttpMethod::GET, headers?, credentials?, mode?)
}

///|
pub async fn post(
  url : String,
  body? : String,
  data? : Json,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  let mHeaders = {}
  if headers is Some(h) {
    for k, v in h {
      mHeaders.set(k, v)
    }
  }
  if data is Some(_) {
    mHeaders.set("Content-Type", "application/json")
  }
  request(
    url,
    http_method=HttpMethod::POST,
    body=if data is Some(d) {
      d.stringify()
    } else if body is Some(b) {
      b
    } else {
      ""
    },
    headers=mHeaders,
    credentials?,
    mode?,
  )
}

///|
pub async fn put(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::PUT,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn delete(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::DELETE,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn patch(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::PATCH,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn options(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::OPTIONS,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn head(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::HEAD,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn connect(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::CONNECT,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn trace(
  url : String,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  request(
    url,
    http_method=HttpMethod::TRACE,
    body?,
    headers?,
    credentials?,
    mode?,
  )
}

///|
pub async fn request_buffer(
  url : String,
  http_method? : HttpMethod,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise NetworkError {
  let options : Map[String, Json] = {}
  options.set("method", http_method.to_string().to_json())
  if body is Some(b) {
    options.set("body", b.to_json())
  }
  if headers is Some(h) {
    options.set("headers", h.to_json())
  }
  if credentials is Some(c) {
    options.set("credentials", c.to_json())
  }
  if mode is Some(m) {
    options.set("mode", m.to_string().to_json())
  }
  match
    (try? @json.parse(
      request_buffer_internal_ffi(
        [url.to_json(), options.to_json()].to_json().stringify(),
      ),
    )) {
    Ok(
      {
        "headers": Object(headers),
        "status": Number(status, ..),
        "data": Array(data),
        ..
      }
    ) =>
      HttpResponse::{
        statusCode: status.to_int(),
        headers: headers
        .iter()
        .map(fn(i : (String, Json)) -> (String, String) {
          (i.0, i.1.as_string().unwrap_or(""))
        })
        .to_array()
        |> Map::from_array,
        data: Bytes::from_array(
          data.map(fn(i : Json) -> Byte {
            i.as_number().unwrap_or(0).to_int().to_byte()
          }),
        ),
      }
    _ => {
      println("Error fetching url: " + url)
      raise NetworkError
    }
  }
}

///|
pub async fn request(
  url : String,
  http_method? : HttpMethod,
  body? : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
  stream~ : Bool = false,
) -> HttpResponse raise NetworkError {
  let options : Map[String, Json] = {}
  if http_method is Some(m) {
    options.set("method", m.to_string().to_json())
  }
  if body is Some(b) {
    options.set("body", b.to_json())
  }
  if headers is Some(h) {
    options.set("headers", h.to_json())
  }
  if credentials is Some(c) {
    options.set("credentials", c.to_json())
  }
  if mode is Some(m) {
    options.set("mode", m.to_string().to_json())
  }
  if stream {
    options.set("stream", stream.to_json())
  }
  match
    (try? @json.parse(
      request_text_internal_ffi(
        [url.to_json(), options.to_json()].to_json().stringify(),
      ),
    )) {
    Ok(
      {
        "headers": Object(headers),
        "status": Number(status, ..),
        "data": String(data),
        ..
      }
    ) =>
      HttpResponse::{
        statusCode: status.to_int(),
        headers: headers
        .iter()
        .map(fn(i : (String, Json)) -> (String, String) {
          (i.0, i.1.as_string().unwrap_or(""))
        })
        .to_array()
        |> Map::from_array,
        data: data.to_bytes(),
      }
    _ => {
      println("Error fetching url: " + url)
      raise NetworkError
    }
  }
}

///|
pub async fn download(
  url : String,
  save_path? : String,
  save_path_fn? : (Map[String, String]) -> String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
) -> HttpResponse raise Error {
  let res = request(
    url,
    http_method=HttpMethod::GET,
    headers?,
    credentials?,
    mode?,
  )
  @fs.write_bytes_to_file(
    if save_path is Some(s) {
      s
    } else if save_path_fn is Some(f) {
      f(res.headers)
    } else {
      "downloaded_file"
    },
    res.data,
  )
  res
}

///|
pub async fn request_stream(
  url : String,
  http_method? : HttpMethod,
  body? : Json,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
  on_chunk~ : (String) -> Unit,
) -> HttpResponse raise NetworkError {
  let options : Map[String, Json] = {}
  if http_method is Some(m) {
    options.set("method", m.to_string().to_json())
  }
  if body is Some(b) {
    options.set("body", b.stringify().to_json())
  }
  if headers is Some(h) {
    options.set("headers", h.to_json())
  }
  if credentials is Some(c) {
    options.set("credentials", c.to_json())
  }
  if mode is Some(m) {
    options.set("mode", m.to_string().to_json())
  }
  match
    (try? @json.parse(
      request_stream_internal_ffi(
        [url.to_json(), options.to_json()].to_json().stringify(),
        on_chunk,
      ),
    )) {
    Ok(
      {
        "headers": Object(headers),
        "status": Number(status, ..),
        "data": String(data),
        ..
      }
    ) =>
      HttpResponse::{
        statusCode: status.to_int(),
        headers: headers
        .iter()
        .map(fn(i : (String, Json)) -> (String, String) {
          (i.0, i.1.as_string().unwrap_or(""))
        })
        .to_array()
        |> Map::from_array,
        data: data.to_bytes(),
      }
    _ => raise NetworkError
  }
}

///|
pub async fn sse_connect(
  url : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
  on_event : (SSEEvent) -> Unit,
) -> HttpResponse raise Error {
  let mut buffer = ""
  request_stream(
    url,
    http_method=HttpMethod::GET,
    headers={ "Accept": "text/event-stream" },
    credentials?,
    mode?,
    on_chunk=fn(chunk : String) {
      buffer = buffer + chunk

      // Process complete events (separated by double newlines)
      let parts = buffer.split("\n\n").to_array()
      if parts.length() > 1 {
        for i = 0; i < parts.length() - 1; i = i + 1 {
          let event_data = parts[i].to_string()
          if event_data != "" {
            let events = SSEEvent::parse(event_data + "\n\n")
            for event in events {
              on_event(event)
            }
          }
        }
        // Keep the last incomplete part in buffer
        buffer = parts[parts.length() - 1].to_string()
      }
    },
  )
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
  on_chunk : (String) -> Unit,
) -> HttpResponse raise NetworkError {
  request_stream(
    url,
    http_method=HttpMethod::GET,
    headers?,
    credentials?,
    mode?,
    on_chunk~,
  )
}

///|
pub async fn post_stream(
  url : String,
  data~ : Json,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode,
  on_chunk : (String) -> Unit,
) -> HttpResponse raise NetworkError {
  request_stream(
    url,
    http_method=HttpMethod::POST,
    body=data,
    headers?,
    credentials?,
    mode?,
    on_chunk~,
  )
}
