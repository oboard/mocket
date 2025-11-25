///|
pub trait StatusCoder {
  to_int(self : Self) -> Int
}

///|
pub impl StatusCoder for Int with to_int(self) -> Int {
  self
}

///|
/// HTTP status codes as registered with IANA.
/// See: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
pub(all) enum StatusCode {
  /// RFC 9110, 15.2.1
  Continue
  /// RFC 9110, 15.2.2
  SwitchingProtocols
  /// RFC 2518, 10.1
  Processing
  /// RFC 8297
  EarlyHints
  /// RFC 9110, 15.3.1
  OK
  /// RFC 9110, 15.3.2
  Created
  /// RFC 9110, 15.3.3
  Accepted
  /// RFC 9110, 15.3.4
  NonAuthoritativeInfo
  /// RFC 9110, 15.3.5
  NoContent
  /// RFC 9110, 15.3.6
  ResetContent
  /// RFC 9110, 15.3.7
  PartialContent
  /// RFC 4918, 11.1
  MultiStatus
  /// RFC 5842, 7.1
  AlreadyReported
  /// RFC 3229, 10.4.1
  IMUsed
  /// RFC 9110, 15.4.1
  MultipleChoices
  /// RFC 9110, 15.4.2
  MovedPermanently
  /// RFC 9110, 15.4.3
  Found
  /// RFC 9110, 15.4.4
  SeeOther
  /// RFC 9110, 15.4.5
  NotModified
  /// RFC 9110, 15.4.6
  UseProxy
  /// RFC 9110, 15.4.8
  TemporaryRedirect
  /// RFC 9110, 15.4.9
  PermanentRedirect
  /// RFC 9110, 15.5.1
  BadRequest
  /// RFC 9110, 15.5.2
  Unauthorized
  /// RFC 9110, 15.5.3
  PaymentRequired
  /// RFC 9110, 15.5.4
  Forbidden
  /// RFC 9110, 15.5.5
  NotFound
  /// RFC 9110, 15.5.6
  MethodNotAllowed
  /// RFC 9110, 15.5.7
  NotAcceptable
  /// RFC 9110, 15.5.8
  ProxyAuthRequired
  /// RFC 9110, 15.5.9
  RequestTimeout
  /// RFC 9110, 15.5.10
  Conflict
  /// RFC 9110, 15.5.11
  Gone
  /// RFC 9110, 15.5.12
  LengthRequired
  /// RFC 9110, 15.5.13
  PreconditionFailed
  /// RFC 9110, 15.5.14
  RequestEntityTooLarge
  /// RFC 9110, 15.5.15
  RequestUriTooLong
  /// RFC 9110, 15.5.16
  UnsupportedMediaType
  /// RFC 9110, 15.5.17
  RequestedRangeNotSatisfiable
  /// RFC 9110, 15.5.18
  ExpectationFailed
  /// RFC 9110, 15.5.19 (Unused)
  Teapot
  /// RFC 9110, 15.5.20
  MisdirectedRequest
  /// RFC 9110, 15.5.21
  UnprocessableEntity
  /// RFC 4918, 11.3
  Locked
  /// RFC 4918, 11.4
  FailedDependency
  /// RFC 8470, 5.2.
  TooEarly
  /// RFC 9110, 15.5.22
  UpgradeRequired
  /// RFC 6585, 3
  PreconditionRequired
  /// RFC 6585, 4
  TooManyRequests
  /// RFC 6585, 5
  RequestHeaderFieldsTooLarge
  /// RFC 7725, 3
  UnavailableForLegalReasons
  /// RFC 9110, 15.6.1
  InternalServerError
  /// RFC 9110, 15.6.2
  NotImplemented
  /// RFC 9110, 15.6.3
  BadGateway
  /// RFC 9110, 15.6.4
  ServiceUnavailable
  /// RFC 9110, 15.6.5
  GatewayTimeout
  /// RFC 9110, 15.6.6
  HttpVersionNotSupported
  /// RFC 2295, 8.1
  VariantAlsoNegotiates
  /// RFC 4918, 11.5
  InsufficientStorage
  /// RFC 5842, 7.2
  LoopDetected
  /// RFC 2774, 7
  NotExtended
  /// RFC 6585, 6
  NetworkAuthenticationRequired
} derive(Show, ToJson)

///|
pub impl StatusCoder for StatusCode with to_int(self) -> Int {
  match self {
    Continue => 100
    SwitchingProtocols => 101
    Processing => 102
    EarlyHints => 103
    OK => 200
    Created => 201
    Accepted => 202
    NonAuthoritativeInfo => 203
    NoContent => 204
    ResetContent => 205
    PartialContent => 206
    MultiStatus => 207
    AlreadyReported => 208
    IMUsed => 226
    MultipleChoices => 300
    MovedPermanently => 301
    Found => 302
    SeeOther => 303
    NotModified => 304
    UseProxy => 305
    TemporaryRedirect => 307
    PermanentRedirect => 308
    BadRequest => 400
    Unauthorized => 401
    PaymentRequired => 402
    Forbidden => 403
    NotFound => 404
    MethodNotAllowed => 405
    NotAcceptable => 406
    ProxyAuthRequired => 407
    RequestTimeout => 408
    Conflict => 409
    Gone => 410
    LengthRequired => 411
    PreconditionFailed => 412
    RequestEntityTooLarge => 413
    RequestUriTooLong => 414
    UnsupportedMediaType => 415
    RequestedRangeNotSatisfiable => 416
    ExpectationFailed => 417
    Teapot => 418
    MisdirectedRequest => 421
    UnprocessableEntity => 422
    Locked => 423
    FailedDependency => 424
    TooEarly => 425
    UpgradeRequired => 426
    PreconditionRequired => 428
    TooManyRequests => 429
    RequestHeaderFieldsTooLarge => 431
    UnavailableForLegalReasons => 451
    InternalServerError => 500
    NotImplemented => 501
    BadGateway => 502
    ServiceUnavailable => 503
    GatewayTimeout => 504
    HttpVersionNotSupported => 505
    VariantAlsoNegotiates => 506
    InsufficientStorage => 507
    LoopDetected => 508
    NotExtended => 510
    NetworkAuthenticationRequired => 511
  }
}

///|
test {
  inspect(StatusCode::OK.to_int(), content="200")
}
