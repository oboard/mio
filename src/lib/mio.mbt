///|
pub fn run(f : async () -> Unit) -> Unit = "%async.run"

///|
pub type! IOError derive(Show)

///|
pub type! NetworkError derive(Show)

///|
pub type! ExecError derive(Show)

///|
pub(all) enum FetchCredentials {
  Omit
  SameOrigin
  Include
} derive(ToJson, Show, Eq)

///|
pub(all) enum FetchMode {
  CORS
  NoCORS
  SameOrigin
  Navigate
} derive(ToJson, Show, Eq)

///|
pub struct HttpResponse {
  mut statusCode : Int
  mut headers : Map[String, String]
  data : Bytes
} derive(Show, Eq)

///|
pub fn HttpResponse::json(self : HttpResponse) -> Json!@json.ParseError {
  @json.parse!(self.text())
}

///|
pub fn HttpResponse::unwrap_json(self : HttpResponse) -> Json {
  self.json?().or(Json::null())
}

///|
pub fn HttpResponse::text(self : HttpResponse) -> String {
  @buffer.from_bytes(self.data).to_string()
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
} derive(ToJson, Show, Eq)

///|
pub(all) struct HttpRequest {
  request_method : HttpMethod
  url : String?
  path : String
  query : String?
  body : Json?
} derive(ToJson, Show, Eq)

///|
pub fn listen(_port : Int) -> Unit!Error {
  fail!("Invalid backend")
}

///|
pub fn handle(_reqMethod : String, _mapping : String) -> Unit {

}

///|
pub fn writeHead(
  self : HttpResponse,
  statusCode : Int,
  headers : Map[String, String]
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(url, http_method=HttpMethod::GET, headers?, credentials?, mode?)
}

///|
pub async fn post(
  url : String,
  body? : String,
  data? : Json,
  headers? : Map[String, String],
  credentials? : FetchCredentials,
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
    url,
    http_method=HttpMethod::POST,
    body=if data is Some(d) {
      d.stringify()
    } else if body is Some(b) {
      b
    } else {
      ""
    },
    headers?,
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
  request!(
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
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
  match
    @json.parse?(
      request_buffer_internal_ffi!(
        [url.to_json(), options.to_json()].to_json().stringify(),
      ),
    ) {
    Ok(
      {
        "headers": Object(headers),
        "status": Number(status),
        "data": Array(data),
        ..
      }
    ) =>
      HttpResponse::{
        statusCode: status.to_int(),
        headers: headers
        .iter()
        .map(fn(i : (String, Json)) -> (String, String) {
          (i.0, i.1.as_string().or(""))
        })
        .to_array()
        |> Map::from_array,
        data: Bytes::from_array(
          data.map(fn(i : Json) -> Byte {
            i.as_number().or(0).to_int().to_byte()
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
  mode? : FetchMode
) -> HttpResponse!NetworkError {
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
  match
    @json.parse?(
      request_text_internal_ffi!(
        [url.to_json(), options.to_json()].to_json().stringify(),
      ),
    ) {
    Ok(
      {
        "headers": Object(headers),
        "status": Number(status),
        "data": String(data),
        ..
      }
    ) =>
      HttpResponse::{
        statusCode: status.to_int(),
        headers: headers
        .iter()
        .map(fn(i : (String, Json)) -> (String, String) {
          (i.0, i.1.as_string().or(""))
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
  mode? : FetchMode
) -> HttpResponse!Error {
  let res = request!(
    url,
    http_method=HttpMethod::GET,
    headers?,
    credentials?,
    mode?,
  )
  @fs.write_bytes_to_file!(
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
test {
  run(fn() {
    if get?("https://echo.apifox.com/anything") is Ok(a) {
      println(a.unwrap_json())
    }
  })
}

///|
test {
  run(fn() {
    if post?("https://echo.apifox.com/anything", data={
        "id": 12,
        "name": "mio",
      })
      is Ok(a) {
      println(a.unwrap_json())
    }
  })
}

///|
test {
  run(fn() {
    if download?("https://api.github.com", save_path="api.json") is Ok(_) {
      println("Downloaded")
    }
  })
}
