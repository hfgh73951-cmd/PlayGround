#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
PROJECT_DIR="$(pwd)"
export PROJECT_DIR
/usr/bin/time -p mkdir -p "$PROJECT_DIR/dist"
/usr/bin/time -p mkdir -p "${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
PORT="${PORT:-3000}"
export PORT
if [ -f "$PROJECT_DIR/package.json" ]; then
  /usr/bin/time -p npm --prefix "$PROJECT_DIR" install --no-audit --no-fund
  if /usr/bin/time -p npm --prefix "$PROJECT_DIR" run --silent build 2>/dev/null; then
    true
  else
    /usr/bin/time -p echo "no build script, skipping npm build"
  fi
fi
if [ ! -f "$PROJECT_DIR/dist/index.html" ]; then
  /usr/bin/time -p cp "$PROJECT_DIR/src/index.html" "$PROJECT_DIR/dist/index.html"
fi
/usr/bin/time -p test -f "$PROJECT_DIR/dist/index.html"
/usr/bin/time -p node -e 'const fs=require("node:fs"),path=require("node:path");const project=process.env.PROJECT_DIR||process.cwd();const dir=path.resolve(project,"dist");const out=process.env.OPENCODE_WEB_DIR||"/home/runner/work/_temp/omgithub-web";fs.mkdirSync(out,{recursive:true});const payload=JSON.stringify({project:path.resolve(project),directory:dir});fs.writeFileSync(path.join(out,"deployment-output.json"),payload);fs.mkdirSync("/home/runner/work/_temp/omgithub-web",{recursive:true});fs.writeFileSync("/home/runner/work/_temp/omgithub-web/deployment-output.json",payload);console.log(payload);'
/usr/bin/time -p cat "${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}/deployment-output.json"
/usr/bin/time -p node -e '
const http=require("node:http"),fs=require("node:fs"),path=require("node:path");
const root=path.resolve(process.env.PROJECT_DIR||process.cwd(),"dist");
const port=Number(process.env.PORT||3000);
const mime={".html":"text/html; charset=utf-8",".js":"application/javascript; charset=utf-8",".css":"text/css; charset=utf-8",".json":"application/json",".svg":"image/svg+xml",".png":"image/png",".jpg":"image/jpeg",".jpeg":"image/jpeg",".webp":"image/webp",".ico":"image/x-icon",".woff2":"font/woff2",".mp3":"audio/mpeg"};
const server=http.createServer((req,res)=>{
 try{
  const u=new URL(req.url,"http://localhost");
  let p=path.resolve(root,"."+decodeURIComponent(u.pathname));
  if(p!==root&&!p.startsWith(root+path.sep)){res.writeHead(404);res.end("Not found");return;}
  let st;try{st=fs.statSync(p)}catch{res.writeHead(404);res.end("Not found");return;}
  if(st.isDirectory())p=path.join(p,"index.html");
  if(!fs.existsSync(p)){res.writeHead(404);res.end("Not found");return;}
  res.setHeader("Content-Type",mime[path.extname(p).toLowerCase()]||"application/octet-stream");
  res.setHeader("Cache-Control","no-cache");
  fs.createReadStream(p).pipe(res);
 }catch(e){res.writeHead(500);res.end("error")}
});
server.listen(port,"0.0.0.0",()=>console.log("asmaa listening on "+port+" serving "+root));
'
