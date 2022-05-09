import express, { Request, Response, NextFunction } from "express";
import path from "path";

const app = express();
const sizeOf = require("image-size");

app.set("trust proxy", 1);

app.use(express.json());

const proxy = require("express-http-proxy");
const { exec } = require("child_process");

function replaceAll(str: string, searchStr: string, replaceStr: string) {
  return str.split(searchStr).join(replaceStr);
}

app.use("/home", express.static(path.join(__dirname, "../vms-web/build")));
app.use("/static", express.static(path.join(__dirname, "./")));
app.use("/search", proxy("localhost:8864"));
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

app.get("/", async (req: Request, res: Response, next: NextFunction) => {
  res.redirect("/home");
});

app.listen(6974, "localhost", () => {
  console.log(`server start localhost:6974`);
});
