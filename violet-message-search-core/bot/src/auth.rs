use std::{
    env,
    time::{SystemTime, UNIX_EPOCH},
};

use sha2::{Digest, Sha512};

fn create_hmac(salt: &str) -> (String, String) {
    let mut hasher = Sha512::new();
    let start = SystemTime::now();
    let since_the_epoch = start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");

    let timestamp = since_the_epoch.as_millis();
    hasher.update(format!("{timestamp:?}{salt}"));
    let hash = hasher.finalize();

    let vtoken = timestamp.to_string();
    let vvalid = (format!("{:x}", hash)[..7]).to_string();

    (vtoken, vvalid)
}

pub fn get1() -> (String, String) {
    let salt = env::var("SALT").expect("token");

    create_hmac(&salt[..])
}

pub fn get2() -> (String, String) {
    let salt = env::var("WSALT").expect("token");

    create_hmac(&salt[..])
}
