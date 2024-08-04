import express, { Request, Response, NextFunction } from "express";
import path from "path";

const app = express();
const sizeOf = require("image-size");

app.set("trust proxy", 1);

app.use(express.json());

const proxy = require("express-http-proxy");
const { exec } = require("child_process");

const sqlite3 = require("sqlite3").verbose();

app.use((req: Request, res: Response, next: NextFunction) => {
  console.log("request: " + req.originalUrl);
  next();
});
app.use("/home/static", express.static(path.join(__dirname, "../vms-web/build/static")));
// app.get('/home/*', function(req, res) {
//   res.sendFile('index.html', {root: path.join(__dirname, '../../client/build/')});
// });
app.get('/home/*', function(req, res) {
  res.sendFile('index.html', {root: path.join(__dirname, "../vms-web/build/")});
});
app.use("/static", express.static(path.join(__dirname, "./")));
app.use("/search", proxy("http://127.0.0.1:8864/"));
app.get(
  "/imageurl/:article/:page",
  async (req: Request, res: Response, next: NextFunction) => {
    const article = req.params["article"];
    const page = req.params["page"];

    exec(
      `gallery-dl -D ./image -f ${article}-{num}.{extension} https://hitomi.la/galleries/${article}.html --range ${page}`,
      (error: any, stdout: string, stderr: any) => {
        if (error) {
          console.log(`error: ${error.message}`);
          return;
        }
        if (stderr) {
          console.log(`stderr: ${stderr}`);
          return;
        }
        // #: 이미 존재
        const size = sizeOf(stdout.replace("#", "").trim());
        res.json({ url: stdout.replace("#", "").trim(), size: size });
      }
    );
  }
);

app.get(
  "/info/:article",
  async (req: Request, res: Response, next: NextFunction) => {
    const db = new sqlite3.Database("./data.db");
    const article = req.params["article"];

    db.all(
      `SELECT * FROM HitomiColumnModel WHERE Id=${article}`,
      [],
      (err: any, rows: any) => {
        res.send(rows[0]);
      }
    );
  }
);

app.get(
  "/ehash/:article",
  async (req: Request, res: Response, next: NextFunction) => {
    const db = new sqlite3.Database("./data.db");
    const article = req.params["article"];

    db.all(
      `SELECT EHash FROM HitomiColumnModel WHERE Id=${article}`,
      [],
      (err: any, rows: any) => {
        res.send(rows[0]["EHash"]);
      }
    );
  }
);

function createUserDB() {
  const db = new sqlite3.Database("./user.db");
  db.run("CREATE TABLE BOOK (id INTEGER  PRIMARY KEY, hash TEXT, body TEXT)");
}

// createUserDB();

const crypto = require("crypto");
app.post(
  "/bookmark",
  async (req: Request, res: Response, next: NextFunction) => {
    const db = new sqlite3.Database("./user.db");
    const body = JSON.stringify(req.body.data);
    const hash = crypto.createHash("md5").update(body).digest("hex");
    db.run("INSERT INTO BOOK(hash, body, search) VALUES (?, ?, ?)", hash, body, req.body.search);
    res.status(200).send();
  }
);

app.post(
  "/unbookmark",
  async (req: Request, res: Response, next: NextFunction) => {
    const db = new sqlite3.Database("./user.db");
    const body = JSON.stringify(req.body);
    const hash = crypto.createHash("md5").update(body).digest("hex");
    db.run("DELETE FROM BOOK WHERE hash=? AND body=?", hash, body);
    res.status(200).send();
  }
);

app.post(
  "/isbookmarked",
  async (req: Request, res: Response, next: NextFunction) => {
    const db = new sqlite3.Database("./user.db");
    const body = JSON.stringify(req.body);
    const hash = crypto.createHash("md5").update(body).digest("hex");
    db.all("SELECT * FROM BOOK WHERE hash=?", [hash], (err: any, rows: any) => {
      res.status(200).send(rows.length.toString());
    });
  }
);

app.get("/", async (req: Request, res: Response, next: NextFunction) => {
  res.redirect("/home");
});

app.listen(6974, "0.0.0.0", () => {
  console.log(`server start localhost:6974`);
});
