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
  "http://[0:0:0:0:0:0:0:1]/",
  "http://[0::1]/",
  "http://[0000:0000:0000:0000:0000:0000:0000:0001]/",
  "http://[0:0:0:0:0:0:0:0]/",
  "http://[0:0:0:0:0:ffff:127.0.0.1]/",
  "http://[0000:0000:0000:0000:0000:ffff:7f00:1]/",
  "http://[::ffff:127.0.0.1]/",
  "http://[::ffff:7f00:1]/",
  "http://[fe80::1]/",
  "http://[fc00::1]/",
  "http://[::1%25lo]/",
  "http://[::1%lo]/",
  "http://[::ffff:7f00:1%25lo]/",
  "http://[fe80::1%eth0]/",
  "http://127.0.0.1../",
  "http://2130706433../",
  "http://127%2e0%2e0%2e1/",
  "http://0.0.0.1/",
  "http://100.64.0.1/",
  "http://100.127.255.254/",
  "http://198.18.0.1/",
  "http://198.19.255.254/",
  "http://224.0.0.1/",
  "http://224.0.0.251/",
  "http://239.255.255.250/",
  "http://240.0.0.1/",
  "http://255.255.255.255/",
  "http://192.0.2.1/",
  "http://198.51.100.1/",
  "http://203.0.113.1/",
  "http://192.88.99.1/",
  "http://192.0.0.8/",
  "http://127.0.0.1\u0000/",
  "http://127.0.0.1\u0000.evil.com/",
  "http://127.0.0.1 ",
  "http://127.0.0.1\t",
  "http://127.0.0.1\n/",
  "http://\t127.0.0.1/",
  "http://[::1",
  "http://[2001:db8::1]127.0.0.1",
  "http://127.0.0.1:8080:8080/",
  "http://127.0.0.1。/",
  "http://127.0.0.1．/",
  "http://127.0.0.1｡/",
  "http://169.254.169.254。/",
  "http://127\\@evil.com/",
  "http://169.254.169.254\\@evil.com/",
  "http://127.0.0.1\\:8080/",
  "http://[2002:7f00:1::]/",
  "http://[2002:0a00::]/",
  "http://[2001:0000:4136:e378:8000:0000:feff:ffff]/",
  "https://0.0.0.0/x",
  "javascript:alert(1)",
  "http://evil.com@127.0.0.1:8080/",
  "http://user:pass@10.0.0.1/x",
  "http://evil.com@[::1]:8080/x",
  "http://2130706433/",
  "http://0x7f000001/",
  "http://0177.0.0.1/",
  "http://127.1/",
  "http://127.0.0.1./",
  ""
]
const allowed = [
  "https://api.svgl.app",
  "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/x.svg",
  "https://cdn.simpleicons.org/docker",
  "http://www.apache.org/foo",
  "https://8.8.8.8/",
  "http://user:pass@example.com/x",
  "http://example.com./",
  "http://[2606:4700::1111]/",
  "http://[2001:4860:4860::8888]/",
  "http://100.128.0.1/",
  "http://198.20.0.1/",
  "http://[2001:4860:4860::8888]/",
  "http://[2606:4700::1111]/",
  "http://[2001:db8::1]/"
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

check("text-node braces are neutralized in JSX output", function() {
  const out = M.toReactComponent('<svg xmlns="http://www.w3.org/2000/svg"><text>{payload()}</text></svg>', "evil", false)
  assert.ok(out.indexOf("{payload()}") === -1, "raw expression must not survive")
  assert.ok(out.indexOf("{'{'}payload(){'}'}") !== -1, "braces encoded as literal-brace expressions")
})

check("CDATA-bracketed expressions are neutralized", function() {
  const out = M.toReactComponent('<svg xmlns="http://www.w3.org/2000/svg"><text><![CDATA[{payload()}]]></text></svg>', "evil", false)
  assert.ok(out.indexOf("{payload()}") === -1, "raw expression must not survive CDATA")
  assert.ok(out.indexOf("{'{'}payload(){'}'}") !== -1, "CDATA braces encoded")
})

check("style content braces are preserved for CSS", function() {
  const out = M.toReactComponent('<svg xmlns="http://www.w3.org/2000/svg"><style>a { fill: red }</style></svg>', "evil", false)
  assert.ok(out.indexOf("a { fill: red }") !== -1, "style CSS kept intact")
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