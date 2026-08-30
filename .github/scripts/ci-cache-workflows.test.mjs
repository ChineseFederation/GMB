import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const scriptsDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = join(scriptsDirectory, '..', '..');
const actionRef = '5a3ec84eff668545956fd18022155c47e93e2684';
const routes = [
  ".github/workflows/chatsdk/ci-sdk.yml",
  ".github/workflows/citizenapp/ci-android.yml",
  ".github/workflows/citizenapp/ci-ios.yml",
  ".github/workflows/citizenchain/ci-node-linux-amd.yml",
  ".github/workflows/citizenchain/ci-node-linux-arm.yaml",
  ".github/workflows/citizenchain/ci-node-macos.yml",
  ".github/workflows/citizenchain/ci-node-windows.yml",
  ".github/workflows/citizenchain/ci-runtime-wasm.yml",
  ".github/workflows/citizensdk/ci-sdk.yml",
  ".github/workflows/citizenserve/ci-cloudflare.yml",
  ".github/workflows/citizenwallet/ci-android.yml",
  ".github/workflows/citizenwallet/ci-ios.yml",
  ".github/workflows/citizenweb/ci-web.yml"
];
const read = relativePath => readFileSync(join(repositoryRoot, relativePath), 'utf8');
function jobBlocks(source) { const jobsAt=source.search(/^jobs:\s*$/m); const body=source.slice(jobsAt); const matches=[...body.matchAll(/^  ([A-Za-z0-9_-]+):\s*(?:#.*)?$/gm)]; return matches.map((match,index)=>body.slice(match.index,index+1<matches.length?matches[index+1].index:body.length)); }
test('all GMB CI route contracts use the unified immutable cache action',()=>{ for(const route of routes){const source=read(route);assert.match(source,/# CI_CACHE_PROTOCOL: ci-v1/);assert.match(source,new RegExp('actions/cache@'+actionRef));assert.match(source,/node \.github\/scripts\/ci-cache\.mjs prepare/);assert.match(source,/node \.github\/scripts\/ci-cache\.mjs wire/);assert.match(source,/node \.github\/scripts\/ci-cache\.mjs sanitize/);assert.doesNotMatch(source,/restore-keys:/);assert.doesNotMatch(source,/Swatinem\/rust-cache@/);} });
test('top-level GMB router wires every CI route but leaves release jobs outside ci-v1',()=>{const source=read('.github/workflows/gmb-repository.yml');assert.match(source,/# CI_CACHE_PROTOCOL: ci-v1/);const blocks=jobBlocks(source);const ciBlocks=blocks.filter(block=>block.includes('id: ci_cache'));for(const route of routes)assert.ok(ciBlocks.some(block=>block.includes(`inputs.pipeline == '${route}'`)));assert.ok(ciBlocks.length>=routes.length);for(const block of ciBlocks){assert.match(block,new RegExp('actions/cache@'+actionRef));assert.doesNotMatch(block,/restore-keys:/);assert.doesNotMatch(block,/Swatinem\/rust-cache@/);}const releaseBlocks=blocks.filter(block=>/release-|Release|release\//.test(block)&&!ciBlocks.includes(block));for(const block of releaseBlocks)assert.doesNotMatch(block,/id: ci_cache/);});


const fullReleaseRoutes = [
  ".github/workflows/chatsdk/release-sdk.yml",
  ".github/workflows/citizenapp/release-android.yml",
  ".github/workflows/citizenapp/release-ios.yml",
  ".github/workflows/citizenchain/release-node-linux-amd.yml",
  ".github/workflows/citizenchain/release-node-linux-arm.yml",
  ".github/workflows/citizenchain/release-node-macos.yml",
  ".github/workflows/citizenchain/release-node-windows.yml",
  ".github/workflows/citizenchain/release-runtime-wasm.yml",
  ".github/workflows/citizensdk/release-sdk.yml",
  ".github/workflows/citizenserve/release-cloudflare.yml",
  ".github/workflows/citizenwallet/release-android.yml",
  ".github/workflows/citizenwallet/release-ios.yml",
  ".github/workflows/citizenweb/release-web.yml"
];
function fullReleaseJobBlocks(source) { const at=source.search(/^jobs:\s*$/m),body=source.slice(at),matches=[...body.matchAll(/^  ([A-Za-z0-9_-]+):\s*(?:#.*)?$/gm)]; return matches.map((match,index)=>body.slice(match.index,index+1<matches.length?matches[index+1].index:body.length)); }
function assertFullRelease(source) { assert.match(source,/# RELEASE_BUILD_MODE: full-v1/); assert.match(source,/CARGO_INCREMENTAL:\s*["']?0/); assert.doesNotMatch(source,/(?:actions\/cache(?:\/restore|\/save)?|Swatinem\/rust-cache|ci-cache\.mjs|CI_INCREMENTAL_ROOT)/); assert.doesNotMatch(source,/^\s+(?:cache:\s*(?!false\s*$)\S+|cache-key:|cache-path:|cache-dependency-path:|bundler-cache:\s*(?:true|yes|1))\s*$/m); assert.doesNotMatch(source,/CARGO_INCREMENTAL:\s*["']?(?:1|true)/i); }
test('GMB Release workflows are full builds without caches', () => { for (const route of fullReleaseRoutes) assertFullRelease(readFileSync('/Users/rhett/GMB/' + route, 'utf8')); const top=readFileSync('/Users/rhett/GMB/' + '.github/workflows/gmb-repository.yml', 'utf8'); const blocks=fullReleaseJobBlocks(top); for (const route of fullReleaseRoutes) { const matched=blocks.filter(block=>block.includes(`inputs.pipeline == '${route}'`)); assert.ok(matched.length>0); for (const block of matched) { assert.match(block,/CARGO_INCREMENTAL:\s*["']?0/); assert.doesNotMatch(block,/(?:actions\/cache(?:\/restore|\/save)?|Swatinem\/rust-cache|ci-cache\.mjs|CI_INCREMENTAL_ROOT)/); } } });


const unifiedProductMatrix = {
  "chatsdk": {
    "ci": [
      ".github/workflows/chatsdk/ci-sdk.yml"
    ],
    "release": [
      ".github/workflows/chatsdk/release-sdk.yml"
    ]
  },
  "citizenapp": {
    "ci": [
      ".github/workflows/citizenapp/ci-android.yml",
      ".github/workflows/citizenapp/ci-ios.yml"
    ],
    "release": [
      ".github/workflows/citizenapp/release-android.yml",
      ".github/workflows/citizenapp/release-ios.yml"
    ]
  },
  "citizenchain": {
    "ci": [
      ".github/workflows/citizenchain/ci-node-linux-amd.yml",
      ".github/workflows/citizenchain/ci-node-linux-arm.yaml",
      ".github/workflows/citizenchain/ci-node-macos.yml",
      ".github/workflows/citizenchain/ci-node-windows.yml",
      ".github/workflows/citizenchain/ci-runtime-wasm.yml"
    ],
    "release": [
      ".github/workflows/citizenchain/release-node-linux-amd.yml",
      ".github/workflows/citizenchain/release-node-linux-arm.yml",
      ".github/workflows/citizenchain/release-node-macos.yml",
      ".github/workflows/citizenchain/release-node-windows.yml",
      ".github/workflows/citizenchain/release-runtime-wasm.yml"
    ]
  },
  "citizensdk": {
    "ci": [
      ".github/workflows/citizensdk/ci-sdk.yml"
    ],
    "release": [
      ".github/workflows/citizensdk/release-sdk.yml"
    ]
  },
  "citizenserve": {
    "ci": [
      ".github/workflows/citizenserve/ci-cloudflare.yml"
    ],
    "release": [
      ".github/workflows/citizenserve/release-cloudflare.yml"
    ]
  },
  "citizenwallet": {
    "ci": [
      ".github/workflows/citizenwallet/ci-android.yml",
      ".github/workflows/citizenwallet/ci-ios.yml"
    ],
    "release": [
      ".github/workflows/citizenwallet/release-android.yml",
      ".github/workflows/citizenwallet/release-ios.yml"
    ]
  },
  "citizenweb": {
    "ci": [
      ".github/workflows/citizenweb/ci-web.yml"
    ],
    "release": [
      ".github/workflows/citizenweb/release-web.yml"
    ]
  }
};
test('GMB all products obey the unified build CI Release flow', () => {
  assert.equal(Object.keys(unifiedProductMatrix).length, 7);
  for (const [product, routes] of Object.entries(unifiedProductMatrix)) {
    assert.ok(routes.ci.length > 0, product + ' must have CI');
    assert.ok(routes.release.length > 0, product + ' must have Release');
    for (const route of routes.ci) {
      const source = readFileSync('/Users/rhett/GMB/' + route, 'utf8');
      assert.match(source, /# CI_CACHE_PROTOCOL: ci-v1/);
      assert.match(source, /ci_cache_save_failure/);
      assert.match(source, /ci_cache_save_success/);
      assert.match(source, /actions\/cache@5a3ec84eff668545956fd18022155c47e93e2684/);
      assert.doesNotMatch(source, /(?:Swatinem\/rust-cache|restore-keys:)/);
    }
    for (const route of routes.release) {
      const source = readFileSync('/Users/rhett/GMB/' + route, 'utf8');
      assert.match(source, /# RELEASE_BUILD_MODE: full-v1/);
      assert.match(source, /CARGO_INCREMENTAL:\s*["']?0/);
      assert.doesNotMatch(source, /(?:actions\/cache(?:\/restore|\/save)?|Swatinem\/rust-cache|ci-cache\.mjs|CI_INCREMENTAL_ROOT)/);
    }
  }
});
