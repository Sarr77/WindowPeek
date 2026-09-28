// Run the unchanged marketplace scanner against local bytes, without publishing.
import { readFileSync, writeFileSync, lstatSync, readlinkSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const arg = name => process.argv.find(v => v.startsWith(`--${name}=`))?.slice(name.length + 3);
const scanner = arg("scanner");
if (!scanner) throw new Error("Pass --scanner=/path/to/omarchy-plugin-marketplace checkout");
const ref = arg("ref");
const git = (...args) => execFileSync("git", ["-C", root, ...args], {maxBuffer:64 * 1024 * 1024});
const files = new Map();
if (ref) {
    for (const entry of git("ls-tree", "-rz", "--full-tree", ref).toString().split("\0").filter(Boolean)) {
        const [meta, path] = entry.split("\t");
        const [mode, type, sha] = meta.split(" ");
        files.set(path, {path, mode, type, sha, bytes: type === "blob" ? git("cat-file", "blob", sha) : Buffer.alloc(0)});
    }
} else {
    for (const path of new Set(git("ls-files", "-co", "--exclude-standard", "-z").toString().split("\0").filter(Boolean))) {
        const absolute = resolve(root, path);
        if (!existsSync(absolute)) continue;
        const stat = lstatSync(absolute);
        if (!stat.isFile() && !stat.isSymbolicLink()) throw new Error(`Unsupported file: ${path}`);
        const bytes = stat.isSymbolicLink() ? Buffer.from(readlinkSync(absolute)) : readFileSync(absolute);
        const mode = stat.isSymbolicLink() ? "120000" : stat.mode & 0o111 ? "100755" : "100644";
        const sha = createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");
        files.set(path, {path, mode, type:"blob", sha, bytes});
    }
}
const tree = [...files.values()].sort((a,b) => a.path.localeCompare(b.path))
    .map(({path, mode, type, sha, bytes}) => ({path, mode, type, sha, size:bytes.length}));
const snapshotHash = createHash("sha256").update(JSON.stringify(tree)).digest("hex");
// The upstream scanner's API requires a SHA. A local run is explicitly NOT a
// public commit or approval: remove this sentinel from the resulting report.
const commit = ref ? git("rev-parse", ref).toString().trim() : "0".repeat(40);
const fetchImpl = async (url, options = {}) => {
    const parsed = new URL(url);
    if (parsed.hostname === "api.github.com") {
        const value = parsed.pathname.includes("/git/trees/") ? {truncated:false, tree}
            : parsed.pathname.includes("/commits/") ? {sha:commit, commit:{tree:{sha:commit}}}
            : {private:false, archived:false, disabled:false};
        return Response.json(value);
    }
    if (parsed.hostname !== "raw.githubusercontent.com") throw new Error(`Unexpected endpoint: ${url}`);
    const path = parsed.pathname.split("/").slice(4).map(decodeURIComponent).join("/");
    const file = files.get(path);
    if (!file) return new Response("", {status:404});
    const range = options.headers?.Range?.match(/^bytes=0-(\d+)$/);
    if (range) {
        const last = Math.min(Number(range[1]), file.bytes.length - 1);
        return new Response(file.bytes.subarray(0,last+1), {status:206, headers:{"content-range":`bytes 0-${last}/${file.bytes.length}`}});
    }
    return new Response(file.bytes, {headers:{"content-length":String(file.bytes.length)}});
};
const { runSecurityBaseline } = await import(pathToFileURL(resolve(scanner, "scripts/security-baseline-scanner.mjs")));
const result = {...await runSecurityBaseline("https://github.com/Sarr77/WindowPeek", commit, {
    fetchImpl, token:"", listedPlugins:[{pluginId:"sarr.windowpeek", manifestPathHint:"manifest.json"}],
})};
if (!ref) delete result.commitSha;
const report = {...result, localRun:true, snapshotHash, snapshotFileCount:files.size,
    scannerCommit:execFileSync("git", ["-C", resolve(scanner), "rev-parse", "HEAD"]).toString().trim()};
if (arg("out")) writeFileSync(resolve(arg("out")), JSON.stringify(report,null,2) + "\n");
console.log(JSON.stringify(report,null,2));
process.exitCode = report.outcome === "passed" ? 0 : 1;
