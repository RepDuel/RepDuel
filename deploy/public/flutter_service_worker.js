'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "b8ab5496890138e1489051307efcc061",
"version.json": "f9b9ca182bcf3036e73147748c6af676",
"favicon.ico": "393460743268e96b3e8944e0811432b5",
"index.html": "c786f0e4c8ccba4995b669b5b86bd582",
"/": "c786f0e4c8ccba4995b669b5b86bd582",
"main.dart.js": "c2deba6c491909ae3e3d2fb23e91a074",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-192.png": "d74d1c9c09cae4c69e8a49ae4be87704",
"icons/Icon-maskable-192.png": "d74d1c9c09cae4c69e8a49ae4be87704",
"icons/Icon-maskable-512.png": "b81985c6c57d072c3318eed1e96704d0",
"icons/Icon-512.png": "b81985c6c57d072c3318eed1e96704d0",
"manifest.json": "2a3f0284b3fba17b6e9ce6b87b66e975",
"assets/AssetManifest.json": "0f520a34ca37cfc827be4c96ed2e434d",
"assets/NOTICES": "94058582a6e2394cfb1e9bb1d0371d5c",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "03c07d603a0f2be26294292719763fd6",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "22b961b5a4ac373e8062d4ddb4b077e3",
"assets/fonts/MaterialIcons-Regular.otf": "ffab1a230fd97161e23b5decff71e25e",
"assets/assets/images/default_female.png": "e7e444a0490e33c8ff31750de714649f",
"assets/assets/images/default_nonbinary.png": "add958cc2aaad911a9137ba6c3146e15",
"assets/assets/images/rare_female.png": "837436fd08700ff03e38ae1e19fd8c4b",
"assets/assets/images/routine_placeholder.svg": "3e70562ed114f309b0d241a7abee69d8",
"assets/assets/images/default_female2.png": "7429bbd0518150debda37995231307c4",
"assets/assets/images/default_male.png": "e52b799e72e2b4d0e0b5f3170b59bc94",
"assets/assets/images/ranks/master.svg": "9ec923b028e2db92fbd9915c7da05999",
"assets/assets/images/ranks/astra.svg": "d079289fb4edf5b1ee4e536f5e98844c",
"assets/assets/images/ranks/celestial.svg": "92cb864874c118fe9e8bfc2dafa0e319",
"assets/assets/images/ranks/bronze.svg": "219a90de664d9193ef5c695388ebe6b8",
"assets/assets/images/ranks/grandmaster.svg": "f325f33cf03c01c66c62267fda8b8269",
"assets/assets/images/ranks/jade.svg": "7ec6247f7f55c1f3be896cafc5cb5818",
"assets/assets/images/ranks/platinum.svg": "497c20d3a202f1ad35664ac877b014f8",
"assets/assets/images/ranks/gold.svg": "70d915e50df87a03e7217857126a6c16",
"assets/assets/images/ranks/nova.svg": "7dd47109bee1606ae6b3712c30c77e5d",
"assets/assets/images/ranks/iron.svg": "e192593c57af3d4133787525a6c163c5",
"assets/assets/images/ranks/unranked.svg": "e192593c57af3d4133787525a6c163c5",
"assets/assets/images/ranks/diamond.svg": "4f61b7510bfcf3a39a0896c921d037f3",
"assets/assets/images/ranks/silver.svg": "a9a6a5bffdc88991c890f6c0e1d28328",
"assets/assets/images/routine_placeholder.png": "1ee4e66f443e38a9f160e7ff2d0c32e9",
"assets/assets/images/logo.svg": "2d198040998da3e460a2a24ac3f936e0",
"assets/assets/images/profile_placeholder.svg": "5c3748cb41ae84ce19b1b7e85b30ec24",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
