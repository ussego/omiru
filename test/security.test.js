const assert = require("node:assert")
const M = require("../Model.js")

let failures = 0
function check(name, fn) {
  try {
    fn()
    console.log("ok   " + name)
  } catch (e) {
    failures++
    console.log("FAIL " + name + " — " + e.message)
  }
}

const blocked = [
  "file:///etc/passwd",
  "ftp://example.com/x",
  "gopher://example.com/",
  "http://127.0.0.1:8080/admin",
  "http://10.0.0.5/x",
  "http://192.168.1.1/x",
  "http://169.254.169.254/latest/meta-data/",
  "http://172.16.0.1/x",
  "http://localhost/x",
  "http://foo.localhost/x",
  "http://[::1]/x",
  "https://0.0.0.0/x",
  "javascript:alert(1)",
  ""
]
const allowed = [
  "https://api.svgl.app",
  "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/x.svg",
  "https://cdn.simpleicons.org/docker",
  "http://www.apache.org/foo"
]

check("routeUrl rejects non-http(s) and private hosts", function() {
  for (const u of blocked) assert.strictEqual(M.routeUrl(u, false), "", "should reject " + u)
  for (const u of allowed) assert.strictEqual(M.routeUrl(u, false), u, "should allow " + u)
})

check("safeUrl accepts public hosts only", function() {
  assert.strictEqual(M.safeUrl("https://api.svgl.app"), "https://api.svgl.app")
  assert.strictEqual(M.safeUrl("http://127.0.0.1/x"), "")
  assert.strictEqual(M.safeUrl("file:///etc/shadow"), "")
})

check("primaryAssetUrl drops file route for svgl logo", function() {
  const logo = { provider: "svgl", id: 1, route: "file:///etc/passwd", hasSvg: true }
  assert.strictEqual(M.primaryAssetUrl(logo, "original"), "")
})

check("dashboard template to private host is dropped", function() {
  const logo = {
    provider: "dashboard", slug: "x", source: "selfhst", formats: ["svg"], hasSvg: true,
    templates: { svg: "http://127.0.0.1:9000/{slug}.svg" }
  }
  assert.strictEqual(M.primaryAssetUrl(logo, "original"), "")
})

check("public dashboard template is kept", function() {
  const logo = {
    provider: "dashboard", slug: "x", source: "selfhst", formats: ["svg"], hasSvg: true,
    templates: { svg: "https://cdn.example.test/{slug}.svg" }
  }
  assert.strictEqual(M.primaryAssetUrl(logo, "original"), "https://cdn.example.test/x.svg")
})

check("style object escapes quotes and backslashes", function() {
  const out = M.styleToObject('x:y" ;z:q\\')
  assert.ok(out.indexOf('\\"') !== -1, "quote escaped: " + out)
  assert.ok(out.indexOf("q\\\\") !== -1, "backslash doubled: " + out)
})

check("text-node braces are entity-encoded in JSX output", function() {
  const out = M.toReactComponent('<svg xmlns="http://www.w3.org/2000/svg"><text>{payload()}</text></svg>', "evil", false)
  assert.ok(out.indexOf("{payload()}") === -1, "raw expression must not survive")
  assert.ok(out.indexOf("&#123;payload()&#125;") !== -1, "braces entity-encoded")
})

check("slugFor collapses traversal and keeps safe filename", function() {
  assert.ok(M.slugFor("https://x/../../etc/passwd", 7).indexOf("/") === -1)
  assert.ok(M.slugFor("https://x/../../etc/passwd", 7).indexOf("..") === -1)
})

check("componentName digit guard prefixes Logo", function() {
  assert.strictEqual(M.componentName("123 abc"), "Logo123Abc")
})

process.exitCode = failures > 0 ? 1 : 0
if (failures === 0) console.log("\nall security regression tests passed")