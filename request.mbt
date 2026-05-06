///|
pub(all) enum Protocol {
  Http
  Https
} derive(Debug, Eq, Compare, Hash, ToJson)

///|
pub fn Protocol::default_port(p : Protocol) -> Int {
  match p {
    Http => 80
    Https => 443
  }
}

///|
pub suberror URIParseError {
  InvalidFormat
  UnsupportedProtocol(String)
} derive(Debug, ToJson)

///|
#warnings("-unused_constructor")
pub suberror RequestError {
  UnsupportedHttpVersion(HttpVersion)
} derive(Debug, ToJson)

///|
#cfg(target="native")
fn ensure_supported_http_version(version : HttpVersion) -> Unit {
  ignore(version)
}

///|
#cfg(target="js")
fn ensure_supported_http_version(_version : HttpVersion) -> Unit {
  ()
}

///|
fn resolve_url(uri : String) -> (Protocol, Int, String, String) raise {
  guard uri.find("://") is Some(protocol_len) else { raise InvalidFormat }
  let protocol = match uri[:protocol_len] {
    "http" => Http
    "https" => Https
    protocol => raise UnsupportedProtocol(protocol.to_owned())
  }
  let uri = uri[protocol_len + 3:]
  let (host, path) = if uri.find("/") is Some(i) {
    (uri[:i].to_owned(), uri[i:].to_owned())
  } else {
    (uri.to_owned(), "/")
  }
  let (host, port) = if host.find(":") is Some(port_start) {
    let port_str = host[port_start + 1:]
    let port = @string.parse_int(port_str) catch { _ => raise InvalidFormat }
    guard port is (1..<65536) else { raise InvalidFormat }
    (host[:port_start].to_owned(), port)
  } else {
    (host, protocol.default_port())
  }
  let path = if path == "" { "/" } else { path }
  (protocol, port, host, path)
}

///|
#cfg(target="native")
async fn perform_request(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
  version? : HttpVersion = Http1,
  verify? : Bool = true,
) -> (Response, &@io.Data) {
  ensure_supported_http_version(version)
  match version {
    Http2 => {
      let response_body = h2_perform_request(
        uri,
        meth,
        headers,
        body,
        proxy?,
        verify~,
      )
      return (response_body.response, response_body.body)
    }
    Http3 => {
      let response_body = h3_perform_request(uri, meth, headers, body, verify~)
      return (response_body.response, response_body.body)
    }
    Http1 => ()
  }
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(
    host,
    headers~,
    protocol~,
    port~,
    proxy?,
    verify~,
  )
  defer client.close()
  let response = client..request(meth, path)..write(body).end_request()
  (response, client.read_all())
}

///|
#cfg(target="js")
async fn perform_request(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
  version? : HttpVersion = Http1,
  verify? : Bool = true,
) -> (Response, &@io.Data) {
  ignore(verify)
  ensure_supported_http_version(version)
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  defer client.close()
  let response = client..request(meth, path)..write(body).end_request()
  (response, client.read_all())
}

///|
async fn perform_request_body_with_options(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
  version? : HttpVersion = Http1,
  verify? : Bool = true,
) -> ResponseBody {
  let (response, body) = perform_request(
    uri,
    meth,
    headers,
    body,
    proxy?,
    version~,
    verify~,
  )
  { response, body }
}

///|
async fn perform_request_body(
  uri : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@io.Data,
  proxy? : Client,
) -> ResponseBody {
  let (response, body) = perform_request(uri, meth, headers, body, proxy?)
  { response, body }
}

///|
/// Perform a HTTP `GET` request to `uri`.
/// Supported protocols are `http://` and `https://`.
/// The HTTP response message and the whole response body will be returned.
///
/// `proxy`, if present, specifies the proxy to use for this request.
/// See `@http.Client::new` for more details.
/// `proxy` is not supported on JavaScript backend.
///
/// See `Client::request` for more details.
pub async fn get(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Get, headers, body, proxy?)
}

///|
/// Similar to `get`, but performs a `PUT` request instead.
pub async fn put(
  uri : String,
  content : &@io.Data,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Put, headers, content, proxy?)
}

///|
/// Similar to `get`, but performs a `POST` request instead.
pub async fn post(
  uri : String,
  content : &@io.Data,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Post, headers, content, proxy?)
}

///|
/// Similar to `get`, but performs a `DELETE` request instead.
pub async fn delete(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Delete, headers, body, proxy?)
}

///|
/// Similar to `get`, but performs a `PATCH` request instead.
pub async fn patch(
  uri : String,
  content : &@io.Data,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Patch, headers, content, proxy?)
}

///|
/// Similar to `get`, but performs a `HEAD` request instead.
pub async fn head(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Head, headers, b"", proxy?)
}

///|
/// Similar to `get`, but performs an `OPTIONS` request instead.
pub async fn options(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> ResponseBody {
  perform_request_body(uri, Options, headers, body, proxy?)
}

///|
/// Similar to `@http.get`, but allow reading response body streamingly.
/// A pair `(response, client)` will be returned,
/// where `response` is the response header from the server,
/// and `client` is the HTTP client that performs the request.
/// `client` can be used to read the content of response body via `@io.Reader`,
/// see `@http.Client` for more details.
///
/// Note that the returned client must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn get_stream(
  uri : String,
  headers? : Map[String, String] = {},
  body? : &@io.Data = b"",
  proxy? : Client,
) -> (Response, Client) {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, headers~, protocol~, port~, proxy?)
  try {
    let response = client..request(Get, path)..write(body).end_request()
    (response, client)
  } catch {
    err => {
      client.close()
      raise err
    }
  }
}

///|
/// Similar to `@http.put`, but allow writing request body streamingly.
/// The return value `client` is the HTTP client that performs the request,
/// it can be used to write the content of request body via `@io.Writer`.
/// Notice that writing to `@http.Client` is buffered,
/// so if you need to send data to the server immediately, `.flush()` must be called.
/// After writing all the content, `.end_request()` must be called
/// to complete the request and obtain response from the server.
/// After that, the response body from the server can be obtained 
/// by using `client` as a `@io.Reader`. See `@http.Client` for more details.
///
/// Note that the returned `client` must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn put_stream(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> Client {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, protocol~, port~, proxy?)
  try client.request(Put, path, extra_headers=headers) catch {
    err => {
      client.close()
      raise err
    }
  } noraise {
    _ => client
  }
}

///|
/// Similar to `@http.post`, but allow writing request body streamingly.
/// The return value `client` is the HTTP client that performs the request,
/// it can be used to write the content of request body via `@io.Writer`.
/// Notice that writing to `@http.Client` is buffered,
/// so if you need to send data to the server immediately, `.flush()` must be called.
/// After writing all the content, `.end_request()` must be called
/// to complete the request and obtain response from the server.
/// After that, the response body from the server can be obtained 
/// by using `client` as a `@io.Reader`. See `@http.Client` for more details.
///
/// Note that the returned `client` must be manually closed via `.close()`
/// to close the underlying connection used for the request.
pub async fn post_stream(
  uri : String,
  headers? : Map[String, String] = {},
  proxy? : Client,
) -> Client {
  let (protocol, port, host, path) = resolve_url(uri)
  let client = Client::connect(host, protocol~, port~, proxy?)
  try client.request(Post, path, extra_headers=headers) catch {
    err => {
      client.close()
      raise err
    }
  } noraise {
    _ => client
  }
}
