
///|
fn RequestMethod::write_show(self : RequestMethod, logger : &Logger) -> Unit {
  match self {
    Get => logger.write_string("Get")
    Head => logger.write_string("Head")
    Post => logger.write_string("Post")
    Put => logger.write_string("Put")
    Delete => logger.write_string("Delete")
    Connect => logger.write_string("Connect")
    Options => logger.write_string("Options")
    Trace => logger.write_string("Trace")
    Patch => logger.write_string("Patch")
  }
}

///|
fn Protocol::write_show(self : Protocol, logger : &Logger) -> Unit {
  match self {
    Http => logger.write_string("Http")
    Https => logger.write_string("Https")
  }
}

///|
fn Response::write_show(self : Response, logger : &Logger) -> Unit {
  logger
  ..write_string("{code: ")
  ..write_object(self.code)
  ..write_string(", reason: ")
  ..write_object(self.reason)
  ..write_string(", headers: ")
  ..write_object(self.headers)
  .write_string("}")
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for RequestMethod

///|
pub impl Show for RequestMethod with output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for Response

///|
pub impl Show for Response with output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for Protocol

///|
pub impl Show for Protocol with output(self, logger) {
  self.write_show(logger)
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for URIParseError

///|
pub impl Show for URIParseError with output(self, logger) {
  match self {
    InvalidFormat => logger.write_string("InvalidFormat")
    UnsupportedProtocol(protocol) =>
      logger
      ..write_string("UnsupportedProtocol(")
      ..write_object(protocol)
      .write_string(")")
  }
}

///|
#cfg(target="native")
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for ProxyError

///|
#cfg(target="native")
pub impl Show for ProxyError with output(self, logger) {
  match self {
    ProxyError(response) => {
      logger.write_string("ProxyError(")
      response.write_show(logger)
      logger.write_string(")")
    }
  }
}

///|
#cfg(target="native")
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for HttpProtocolError

///|
#cfg(target="native")
pub impl Show for HttpProtocolError with output(self, logger) {
  match self {
    BadRequest => logger.write_string("BadRequest")
    HttpVersionNotSupported(version) =>
      logger
      ..write_string("HttpVersionNotSupported(")
      ..write_object(version)
      .write_string(")")
    NotImplemented => logger.write_string("NotImplemented")
  }
}
