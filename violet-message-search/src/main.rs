use std::path::PathBuf;

use chrono::Local;
use lazy_static::lazy_static;
use message::mobile::{self, Scope};
use message::{
    article_lists, load_messages, search_article, search_partial_contains,
    search_partial_contains_many, search_partial_contains_range, search_similar,
    search_similar_many, search_similar_range, MessageResult,
};
use rocket::http::Status;
use rocket::serde::json::Json;
use serde::Deserialize;
use structopt::StructOpt;

mod binding;
mod cache;
mod displant;
mod message;

#[macro_use]
extern crate rocket;

#[derive(Debug, StructOpt)]
#[structopt(name = "fast-search", about = "Fast Search for Comic Message")]
struct Opt {
    host: String,
    port: usize,

    #[structopt(long, parse(from_os_str), default_value = "./merged-0.fscm")]
    data_paths: Vec<PathBuf>,

    /// Scan FSCM files with bounded buffers instead of loading the entire corpus.
    #[structopt(long)]
    mobile: bool,
    /// Mobile allocation budget (MiB), not an OS-enforced RSS limit.
    #[structopt(long, default_value = "512")]
    memory_budget_mb: usize,
    /// Rayon workers in mobile mode.
    #[structopt(long, default_value = "4")]
    search_threads: usize,
}

#[derive(Debug, Deserialize)]
struct WorkSearchRequest {
    ids: Vec<u32>,
    query: String,
    limit: Option<usize>,
}

lazy_static! {
    static ref OPT: Opt = Opt::from_args();
}

const DEFAULT_TAKE: usize = 1000;
const MAX_TAKE: usize = 1000;

fn current_date_time() -> String {
    Local::now().format("%Y-%m-%d.%H:%M:%S").to_string()
}

fn normalize_take(limit: Option<usize>) -> usize {
    limit.unwrap_or(DEFAULT_TAKE).clamp(1, MAX_TAKE)
}

fn parse_id_range(min: Option<&str>, max: Option<&str>) -> Result<(u32, u32), Status> {
    let parse = |value: &str| {
        if value.is_empty() || !value.bytes().all(|byte| byte.is_ascii_digit()) {
            return Err(Status::BadRequest);
        }
        value.parse::<u32>().map_err(|_| Status::BadRequest)
    };
    let bounds = (
        min.map(parse).transpose()?.unwrap_or(0),
        max.map(parse).transpose()?.unwrap_or(u32::MAX),
    );
    if bounds.0 > bounds.1 {
        return Err(Status::BadRequest);
    }
    Ok(bounds)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_take_defaults_and_clamps_requested_limit() {
        assert_eq!(normalize_take(None), 1000);
        assert_eq!(normalize_take(Some(0)), 1);
        assert_eq!(normalize_take(Some(25)), 25);
        assert_eq!(normalize_take(Some(5000)), 1000);
    }

    #[test]
    fn invalid_http_bounds_are_rejected() {
        let client = rocket::local::blocking::Client::tracked(
            rocket::build()
                .mount("/contains", routes![contains])
                .mount("/similar", routes![similar]),
        )
        .unwrap();
        for mode in ["contains", "similar"] {
            assert_eq!(
                client
                    .get(format!("/{mode}/test?id_min=20&id_max=10"))
                    .dispatch()
                    .status(),
                Status::BadRequest
            );
            assert!(!client
                .get(format!("/{mode}/test?id_min=abc"))
                .dispatch()
                .status()
                .class()
                .is_success());
            assert!(!client
                .get(format!("/{mode}/test?id_max=4294967296"))
                .dispatch()
                .status()
                .class()
                .is_success());
        }
    }
}

#[get("/<query>?<limit>&<id_min>&<id_max>")]
async fn similar(
    query: &str,
    limit: Option<usize>,
    id_min: Option<&str>,
    id_max: Option<&str>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(limit);
    println!(
        "({}) similar: {} (take={})",
        current_date_time(),
        query,
        take
    );
    let (min, max) = parse_id_range(id_min, id_max)?;
    if mobile::enabled() {
        let scope = if id_min.is_none() && id_max.is_none() {
            Scope::All
        } else {
            Scope::Range(min, max)
        };
        return mobile_search(scope, query, false, take).await;
    }
    Ok(Json(if id_min.is_some() || id_max.is_some() {
        search_similar_range(min, max, query, take)
    } else {
        search_similar(None, query, take)
    }))
}

#[get("/<query>?<limit>&<id_min>&<id_max>")]
async fn contains(
    query: &str,
    limit: Option<usize>,
    id_min: Option<&str>,
    id_max: Option<&str>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(limit);
    println!(
        "({}) contains: {} (take={})",
        current_date_time(),
        query,
        take
    );
    let (min, max) = parse_id_range(id_min, id_max)?;
    if mobile::enabled() {
        let scope = if id_min.is_none() && id_max.is_none() {
            Scope::All
        } else {
            Scope::Range(min, max)
        };
        return mobile_search(scope, query, true, take).await;
    }
    Ok(Json(if id_min.is_some() || id_max.is_some() {
        search_partial_contains_range(min, max, query, take)
    } else {
        search_partial_contains(None, query, take)
    }))
}

#[get("/<id>/<query>?<limit>")]
async fn wsimilar(
    id: u32,
    query: &str,
    limit: Option<usize>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(limit);
    if mobile::enabled() {
        return mobile_search(Scope::Article(id), query, false, take).await;
    }
    println!(
        "({}) wsimilar: {} - {} (take={})",
        current_date_time(),
        id,
        query,
        take
    );
    Ok(Json(search_similar(Some(id), query, take)))
}

#[post("/", format = "json", data = "<request>")]
async fn wsimilar_many(
    request: Json<WorkSearchRequest>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(request.limit);
    if mobile::enabled() {
        return mobile_search(
            Scope::Many(request.ids.clone()),
            &request.query,
            false,
            take,
        )
        .await;
    }
    println!(
        "({}) wsimilar-many: {} works - {} (take={})",
        current_date_time(),
        request.ids.len(),
        request.query,
        take
    );
    Ok(Json(search_similar_many(
        &request.ids,
        &request.query,
        take,
    )))
}

#[get("/<id>/<query>?<limit>")]
async fn wcontains(
    id: u32,
    query: &str,
    limit: Option<usize>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(limit);
    if mobile::enabled() {
        return mobile_search(Scope::Article(id), query, true, take).await;
    }
    println!(
        "({}) wcontains: {} - {} (take={})",
        current_date_time(),
        id,
        query,
        take
    );
    Ok(Json(search_partial_contains(Some(id), query, take)))
}

#[post("/", format = "json", data = "<request>")]
async fn wcontains_many(
    request: Json<WorkSearchRequest>,
) -> Result<Json<Vec<MessageResult>>, Status> {
    let take = normalize_take(request.limit);
    if mobile::enabled() {
        return mobile_search(Scope::Many(request.ids.clone()), &request.query, true, take).await;
    }
    println!(
        "({}) wcontains-many: {} works - {} (take={})",
        current_date_time(),
        request.ids.len(),
        request.query,
        take
    );
    Ok(Json(search_partial_contains_many(
        &request.ids,
        &request.query,
        take,
    )))
}

#[get("/<id>")]
async fn article(id: u32) -> Result<Json<Vec<MessageResult>>, Status> {
    if mobile::enabled() {
        return mobile_task(move || mobile::article(id)).await;
    }
    println!("({}) article: {}", current_date_time(), id);
    Ok(Json(search_article(id)))
}

#[get("/")]
async fn lists() -> Result<Json<Vec<u32>>, Status> {
    if mobile::enabled() {
        return mobile_task(mobile::lists).await;
    }
    println!("({}) lists", current_date_time());
    Ok(Json(article_lists()))
}

fn mobile_response<T>(result: std::io::Result<T>) -> Result<Json<T>, Status> {
    result.map(Json).map_err(|error| {
        eprintln!("[mobile] {error}");
        match error.kind() {
            std::io::ErrorKind::WouldBlock => Status::ServiceUnavailable,
            std::io::ErrorKind::Interrupted => Status::Conflict,
            std::io::ErrorKind::InvalidInput => Status::BadRequest,
            _ => Status::InternalServerError,
        }
    })
}

async fn mobile_task<T: Send + 'static>(
    task: impl FnOnce() -> std::io::Result<T> + Send + 'static,
) -> Result<Json<T>, Status> {
    let result = rocket::tokio::task::spawn_blocking(task)
        .await
        .map_err(|_| Status::InternalServerError)?;
    mobile_response(result)
}

async fn mobile_search(
    scope: Scope,
    query: &str,
    contains: bool,
    take: usize,
) -> Result<Json<Vec<MessageResult>>, Status> {
    if query.len() > 4096 {
        return Err(Status::BadRequest);
    }
    let query = query.to_owned();
    mobile_task(move || mobile::search(scope, &query, contains, take)).await
}

#[get("/status")]
fn mobile_status() -> Json<Option<mobile::Progress>> {
    Json(mobile::progress())
}

#[post("/cancel")]
fn mobile_cancel() -> Json<bool> {
    Json(mobile::cancel())
}

#[launch]
fn rocket() -> _ {
    if OPT.mobile {
        assert!(
            (1..=8).contains(&OPT.search_threads),
            "search threads must be 1..8"
        );
        rayon::ThreadPoolBuilder::new()
            .num_threads(OPT.search_threads)
            .build_global()
            .expect("Rayon initialization failed");
        mobile::initialize(&OPT.data_paths, OPT.memory_budget_mb)
            .expect("mobile initialization failed");
    } else {
        OPT.data_paths
            .iter()
            .for_each(|path| load_messages(path.clone()));
    }

    println!("fscm has launched from http://{}:{}", OPT.host, OPT.port);

    rocket::build()
        .configure(
            // https://api.rocket.rs/v0.4/rocket/config/
            rocket::Config::figment()
                .merge(("log_level", "off"))
                .merge(("address", OPT.host.clone()))
                .merge(("port", OPT.port)),
        )
        .mount("/similar", routes![similar])
        .mount("/contains", routes![contains])
        .mount("/wsimilar", routes![wsimilar, wsimilar_many])
        .mount("/wcontains", routes![wcontains, wcontains_many])
        .mount("/article", routes![article])
        .mount("/lists", routes![lists])
        .mount("/mobile", routes![mobile_status, mobile_cancel])
}
