"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const path_1 = __importDefault(require("path"));
const app = (0, express_1.default)();
const sizeOf = require("image-size");
app.set("trust proxy", 1);
app.use(express_1.default.json());
const proxy = require("express-http-proxy");
const { exec } = require("child_process");
const sqlite3 = require("sqlite3").verbose();
app.use((req, res, next) => {
    console.log("request: " + req.originalUrl);
    next();
});
app.use("/home", express_1.default.static(path_1.default.join(__dirname, "../vms-web/build")));
app.use("/static", express_1.default.static(path_1.default.join(__dirname, "./")));
app.use("/search", proxy("localhost:8864"));
app.get("/imageurl/:article/:page", (req, res, next) => __awaiter(void 0, void 0, void 0, function* () {
    const article = req.params["article"];
    const page = req.params["page"];
    exec(`gallery-dl -D ./image -f ${article}-{num}.{extension} https://hitomi.la/galleries/${article}.html --range ${page}`, (error, stdout, stderr) => {
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
    });
}));
app.get("/info/:article", (req, res, next) => __awaiter(void 0, void 0, void 0, function* () {
    const db = new sqlite3.Database("./data.db");
    const article = req.params["article"];
    db.all(`SELECT * FROM HitomiColumnModel WHERE Id=${article}`, [], (err, rows) => {
        res.send(rows[0]);
    });
}));
app.get("/ehash/:article", (req, res, next) => __awaiter(void 0, void 0, void 0, function* () {
    const db = new sqlite3.Database("./data.db");
    const article = req.params["article"];
    db.all(`SELECT EHash FROM HitomiColumnModel WHERE Id=${article}`, [], (err, rows) => {
        res.send(rows[0]["EHash"]);
    });
}));
app.get("/", (req, res, next) => __awaiter(void 0, void 0, void 0, function* () {
    res.redirect("/home");
}));
app.listen(6974, "localhost", () => {
    console.log(`server start localhost:6974`);
});
