///|
pub(all) enum RequestMethod {
  Get
  Head
  Post
  Put
  Delete
  Connect
  Options
  Trace
  Patch
} derive(Debug, Eq, Compare, Hash, ToJson)

///|
pub(all) enum HttpVersion {
  Http1
  Http2
  Http3
} derive(Debug, Eq, Compare, Hash, ToJson)

///|
pub(all) struct Response {
  code : Int
  reason : String
  headers : Map[String, String]
  /// The list of cookies specified in `Set-Cookie` headers.
  ///
  /// JS backend note: browsers forbid JS code from accessing raw cookie values,
  /// so this field is always empty on JS backend.
  cookies : Array[Cookie]
} derive(Debug, ToJson)

///|
pub(all) struct ResponseBody {
  response : Response
  body : &@io.Data
}

///|
pub fn ResponseBody::binary(self : ResponseBody) -> Bytes {
  self.body.binary()
}

///|
pub fn ResponseBody::text(self : ResponseBody) -> String raise {
  self.body.text()
}

///|
pub fn ResponseBody::json(self : ResponseBody) -> Json raise {
  self.body.json()
}

///|
pub struct Cookie {
  name : String
  value : String
  path : String?
  expires_raw : String?
  max_age : Int64?
  domain : String?
  secure : Bool
  http_only : Bool
  extensions : Array[String]
} derive(Debug, ToJson)

///|
pub fn Cookie::Cookie(
  name : String,
  value : String,
  path? : String,
  expires_raw? : String,
  max_age? : Int64,
  domain? : String,
  secure? : Bool = false,
  http_only? : Bool = false,
  extensions? : Array[String] = [],
) -> Cookie {
  Cookie::new(
    name,
    value,
    path?,
    expires_raw?,
    max_age?,
    domain?,
    secure~,
    http_only~,
    extensions~,
  )
}
