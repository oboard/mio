///|
pub type! IOError  derive(Show)

///|
pub type! NetworkError  derive(Show)

///|
pub type! ExecError  derive(Show)

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
  data : String
} derive(ToJson, Show, Eq)

///|
pub fn HttpResponse::json(self : HttpResponse) -> Json!@json.ParseError {
  @json.parse!(self.data)
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
pub fn request(_fun : (HttpRequest, HttpResponse) -> Unit!Error) -> Unit!Error {
  fail!("Invalid backend")
}

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
pub fn end(self : HttpResponse, _body : Json) -> Unit {
  end_internal(self, _body)
}

///|
pub async fn fetch(
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
      fetch_internal!([url.to_json(), options.to_json()].to_json().stringify()),
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
        data,
      }
    _ => {
      println("Error fetching url: " + url)
      raise NetworkError
    }
  }
}
