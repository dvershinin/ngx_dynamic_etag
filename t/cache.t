use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: ETag with proxy_cache (MISS then HIT) should not be empty-MD5
--- http_config
    # use path relative to nginx prefix, outside servroot (t/cache)
    proxy_cache_path ../_cache levels=1:2 keys_zone=testcache:10m inactive=60m;
--- config
    location = /origin1 {
        return 200 "alpha123\n";
    }
    location = /cache1 {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_cache testcache;
        proxy_cache_key $uri;
        proxy_cache_valid 200 30m;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/origin1;
        add_header X-Cache-Status $upstream_cache_status always;
    }
--- request
    GET /cache1
--- response_body_like
alpha123
--- response_headers_like
ETag: "7ea4d7d78b01d533da85bf0e4fcd1a75"
X-Cache-Status: (MISS|BYPASS)
--- request
    GET /cache1
--- response_body_like
alpha123
--- response_headers_like
ETag: "7ea4d7d78b01d533da85bf0e4fcd1a75"
X-Cache-Status: (MISS|HIT|EXPIRED|REVALIDATED)


=== TEST 2: Different cached URIs should have different ETags (both non-empty)
--- http_config
    # use path relative to nginx prefix, outside servroot (t/cache2)
    proxy_cache_path ../_cache2 levels=1:2 keys_zone=testcache2:10m inactive=60m;
--- config
    location = /originA {
        return 200 "content-A\n";
    }
    location = /originB {
        return 200 "content-B\n";
    }
    location = /cacheA {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_cache testcache2;
        proxy_cache_key $uri;
        proxy_cache_valid 200 30m;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/originA;
    }
    location = /cacheB {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_cache testcache2;
        proxy_cache_key $uri;
        proxy_cache_valid 200 30m;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/originB;
    }
--- request
    GET /cacheA
--- response_headers_like
ETag: "b1c1868e354feafe0944991dc03002d1"
--- response_body_like
content-A
--- request
    GET /cacheB
--- response_headers_like
ETag: "17a11a3fef795a3a3fdf618aa915325e"
--- response_body_like
content-B


