// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

const mysql = require("sync-mysql");
const config = require("config");

const host = config.get("db.host");
const port = config.get("db.port");
const user = config.get("db.user");
const password = config.get("db.password");
const database = config.get("db.database");

module.exports = function () {
  return new mysql({
    host: host,
    port: port,
    user: user,
    password: password,
    database: database,
  });
};
