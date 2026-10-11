#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
if [ -z "${CAPTURE_URL:-}" ]; then
  /usr/bin/time -p echo "CAPTURE_URL is required" >&2
  exit 1
fi
if [ -z "${CAPTURE_DIR:-}" ]; then
  /usr/bin/time -p echo "CAPTURE_DIR is required" >&2
  exit 1
fi
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p echo "capturing $CAPTURE_URL into $CAPTURE_DIR"
/usr/bin/time -p node -e '
const fs=require("node:fs"),path=require("node:path"),os=require("node:os");
const {createRequire}=require("node:module");
(async()=>{
 const url=process.env.CAPTURE_URL,output=process.env.CAPTURE_DIR;
 if(!url||!output){console.error("Set CAPTURE_URL and CAPTURE_DIR.");process.exit(1);}
 const runtime=path.join(os.homedir(),".local/share/omgithub-playwright");
 const req=createRequire(path.join(runtime,"package.json"));
 const {chromium}=req("playwright");
 let config={browser:{launchOptions:{headless:false}}};
 try{config=JSON.parse(fs.readFileSync(path.join(runtime,process.platform==="darwin"?"metal.json":"linux.json"),"utf8"))}catch(e){console.error("playwright config missing: "+e.message);process.exit(1);}
 if(process.platform==="linux"){try{process.env.DISPLAY=process.env.DISPLAY||":"+fs.readFileSync(path.join(runtime,"display"),"utf8").trim()}catch{}}
 const transient=(e)=>{throw Object.assign(e instanceof Error?e:new Error(String(e)),{exitCode:75})};
 let browser;
 try{
  browser=await chromium.launch({...config.browser.launchOptions,timeout:30000}).catch(transient);
  for(const [name,width,height] of [["desktop",1440,900],["mobile",390,844]]){
   const page=await browser.newPage({viewport:{width,height}}).catch(transient);
   try{
    page.setDefaultTimeout(30000);
    page.on("pageerror",(e)=>console.error("pageerror: "+e.message));
    const response=await page.goto(url,{waitUntil:"load",timeout:45000}).catch(transient);
    const status=response?response.status():0;
    if(!response||!response.ok()){
     const code=(!response||[408,429,500,502,503,504].includes(status))?75:1;
     throw Object.assign(new Error("HTTP "+(status||"no-response")+" loading preview"),{exitCode:code});
    }
    await page.locator("body").waitFor({state:"visible",timeout:30000}).catch(transient);
    await page.waitForFunction(()=>document.fonts?document.fonts.status==="loaded":true,{timeout:30000}).catch(()=>{});
    await page.waitForTimeout(1500);
    const title=(await page.title().catch(()=> "")).trim();
    const text=(await page.locator("body").innerText().catch(()=> "")).trim();
    if(!text||text.length<20){throw Object.assign(new Error("rendered content too small ("+text.length+" chars, title="+JSON.stringify(title)+")"),{exitCode:1})}
    const file=path.join(output,"final-"+name+".png");
    await page.screenshot({path:file,timeout:30000}).catch((e)=>{if(e&&e.name==="TimeoutError")transient(e);throw e});
    const st=fs.statSync(file);
    if(st.size<5000){throw Object.assign(new Error("screenshot too small: "+file+" "+st.size+" bytes"),{exitCode:1})}
    console.log("captured "+name+": "+file+" ("+st.size+" bytes)");
   }finally{await page.close().catch(()=>{})}
  }
 }catch(e){console.error(e&&e.stack||e);process.exit(e&&e.exitCode||1)}
 finally{try{if(browser)await browser.close()}catch(e){console.error(e);process.exitCode=process.exitCode||75}}
})();
'
/usr/bin/time -p ls -lh "$CAPTURE_DIR/final-desktop.png" "$CAPTURE_DIR/final-mobile.png"
/usr/bin/time -p test -s "$CAPTURE_DIR/final-desktop.png"
/usr/bin/time -p test -s "$CAPTURE_DIR/final-mobile.png"
/usr/bin/time -p echo "capture done, app left running"
