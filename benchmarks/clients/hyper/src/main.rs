use bytes::Bytes;
use http_body_util::{BodyExt, Empty};
use hyper::{Request, StatusCode};
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_util::client::legacy::Client;
use hyper_util::rt::TokioExecutor;
use serde::Serialize;
use std::env;
use std::error::Error;
use std::time::Instant;

#[derive(Serialize)]
struct ResultRow {
    runtime: &'static str,
    requests: usize,
    warmup: usize,
    elapsed_ms: f64,
    requests_per_sec: f64,
    bytes: usize,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    let args = Args::parse();
    let mut connector = HttpConnector::new();
    connector.enforce_http(true);
    let client: Client<_, Empty<Bytes>> =
        Client::builder(TokioExecutor::new()).build(connector);

    for _ in 0..args.warmup {
        issue_request(&client, &args.url).await?;
    }

    let started = Instant::now();
    let mut bytes = 0;
    for _ in 0..args.requests {
        bytes += issue_request(&client, &args.url).await?;
    }
    let elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;

    println!(
        "{}",
        serde_json::to_string(&ResultRow {
            runtime: "hyper",
            requests: args.requests,
            warmup: args.warmup,
            elapsed_ms,
            requests_per_sec: args.requests as f64 * 1000.0 / elapsed_ms,
            bytes,
        })?
    );
    Ok(())
}

async fn issue_request(
    client: &Client<HttpConnector, Empty<Bytes>>,
    url: &str,
) -> Result<usize, Box<dyn Error + Send + Sync>> {
    let request = Request::builder()
        .method("GET")
        .uri(url)
        .body(Empty::<Bytes>::new())?;
    let response = client.request(request).await?;
    let status = response.status();
    let body = response.into_body().collect().await?.to_bytes();
    if status != StatusCode::OK {
        return Err(format!("unexpected status {}", status).into());
    }
    Ok(body.len())
}

struct Args {
    url: String,
    requests: usize,
    warmup: usize,
}

impl Args {
    fn parse() -> Self {
        let mut url = "http://127.0.0.1:3200/payload".to_owned();
        let mut requests = 10_000;
        let mut warmup = 200;

        let mut args = env::args().skip(1);
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--url" => url = args.next().expect("expected URL"),
                "--requests" => {
                    requests = args
                        .next()
                        .expect("expected request count")
                        .parse()
                        .expect("invalid request count")
                }
                "--warmup" => {
                    warmup = args
                        .next()
                        .expect("expected warmup count")
                        .parse()
                        .expect("invalid warmup count")
                }
                "-h" | "--help" => {
                    println!(
                        "Usage: hyper-client --url URL --requests N --warmup N"
                    );
                    std::process::exit(0);
                }
                _ => panic!("unknown option `{}`", arg),
            }
        }

        Self {
            url,
            requests,
            warmup,
        }
    }
}
