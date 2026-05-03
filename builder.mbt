///|
pub struct RequestClient {
  headers : Map[String, String]
  proxy : Client?
  timeout : Int?
  version : HttpVersion
  verify : Bool
}

///|
pub struct ClientBuilder {
  headers : Map[String, String]
  mut proxy : Client?
  mut timeout : Int?
  mut version : HttpVersion
  mut verify : Bool
}

///|
pub fn ClientBuilder::new() -> ClientBuilder {
  { headers: {}, proxy: None, timeout: None, version: Http1, verify: true }
}

///|
pub fn ClientBuilder::default_header(
  self : ClientBuilder,
  key : String,
  value : String,
) -> ClientBuilder {
  self.headers[key] = value
  self
}

///|
pub fn ClientBuilder::default_headers(
  self : ClientBuilder,
  headers : Map[String, String],
) -> ClientBuilder {
  for key, value in headers {
    self.headers[key] = value
  }
  self
}

///|
pub fn ClientBuilder::proxy(
  self : ClientBuilder,
  proxy : Client,
) -> ClientBuilder {
  self.proxy = Some(proxy)
  self
}

///|
pub fn ClientBuilder::timeout(
  self : ClientBuilder,
  millis : Int,
) -> ClientBuilder {
  self.timeout = Some(millis)
  self
}

///|
pub fn ClientBuilder::http1_only(self : ClientBuilder) -> ClientBuilder {
  self.version = Http1
  self
}

///|
pub fn ClientBuilder::http2_prior_knowledge(
  self : ClientBuilder,
) -> ClientBuilder {
  self.version = Http2
  self
}

///|
pub fn ClientBuilder::http3_prior_knowledge(
  self : ClientBuilder,
) -> ClientBuilder {
  self.version = Http3
  self
}

///|
pub fn ClientBuilder::danger_accept_invalid_certs(
  self : ClientBuilder,
  enabled : Bool,
) -> ClientBuilder {
  self.verify = !enabled
  self
}

///|
pub fn ClientBuilder::build(self : ClientBuilder) -> RequestClient {
  {
    headers: self.headers,
    proxy: self.proxy,
    timeout: self.timeout,
    version: self.version,
    verify: self.verify,
  }
}

///|
pub fn RequestClient::new() -> RequestClient {
  ClientBuilder::new().build()
}

///|
pub fn RequestClient::builder() -> ClientBuilder {
  ClientBuilder::new()
}

///|
pub fn RequestClient::request(
  self : RequestClient,
  meth : RequestMethod,
  uri : String,
) -> RequestBuilder {
  { client: self, meth, uri, headers: {}, body: b"" }
}

///|
pub fn RequestClient::get(self : RequestClient, uri : String) -> RequestBuilder {
  self.request(Get, uri)
}

///|
pub fn RequestClient::post(
  self : RequestClient,
  uri : String,
) -> RequestBuilder {
  self.request(Post, uri)
}

///|
pub fn RequestClient::put(self : RequestClient, uri : String) -> RequestBuilder {
  self.request(Put, uri)
}

///|
pub fn RequestClient::patch(
  self : RequestClient,
  uri : String,
) -> RequestBuilder {
  self.request(Patch, uri)
}

///|
pub fn RequestClient::delete(
  self : RequestClient,
  uri : String,
) -> RequestBuilder {
  self.request(Delete, uri)
}

///|
pub fn RequestClient::head(
  self : RequestClient,
  uri : String,
) -> RequestBuilder {
  self.request(Head, uri)
}

///|
pub fn RequestClient::options(
  self : RequestClient,
  uri : String,
) -> RequestBuilder {
  self.request(Options, uri)
}

///|
pub struct RequestBuilder {
  client : RequestClient
  meth : RequestMethod
  uri : String
  headers : Map[String, String]
  mut body : &@io.Data
}

///|
pub fn RequestBuilder::header(
  self : RequestBuilder,
  key : String,
  value : String,
) -> RequestBuilder {
  self.headers[key] = value
  self
}

///|
pub fn RequestBuilder::headers(
  self : RequestBuilder,
  headers : Map[String, String],
) -> RequestBuilder {
  for key, value in headers {
    self.headers[key] = value
  }
  self
}

///|
pub fn RequestBuilder::body(
  self : RequestBuilder,
  body : &@io.Data,
) -> RequestBuilder {
  self.body = body
  self
}

///|
pub fn RequestBuilder::json(
  self : RequestBuilder,
  value : Json,
) -> RequestBuilder {
  self.header("Content-Type", "application/json").body(value.stringify())
}

///|
fn RequestBuilder::merged_headers(self : RequestBuilder) -> Map[String, String] {
  let headers = {}
  for key, value in self.client.headers {
    headers[key] = value
  }
  for key, value in self.headers {
    headers[key] = value
  }
  headers
}

///|
async fn RequestBuilder::send_once(self : RequestBuilder) -> ResponseBody {
  let proxy = self.client.proxy
  perform_request_body_with_options(
    self.uri,
    self.meth,
    self.merged_headers(),
    self.body,
    proxy?,
    version=self.client.version,
    verify=self.client.verify,
  )
}

///|
pub async fn RequestBuilder::send(self : RequestBuilder) -> ResponseBody {
  let request = () => self.send_once()
  if self.client.timeout is Some(timeout) {
    @async.with_timeout(timeout, request)
  } else {
    request()
  }
}
