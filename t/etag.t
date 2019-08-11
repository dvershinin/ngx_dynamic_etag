use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: etag with proxy_pass
--- config
    location = /hello {
        return 200 "hello world\n";
    }
    location = /hello-proxy {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    GET /hello-proxy
--- response_body
hello world
--- response_headers
ETag: "6f5902ac237024bdd0c176cb93063dc4"



=== TEST 2: etag with proxy_pass differs
--- config
    location = /hello {
        return 200 "hello earth\n";
    }
    location = /hello-proxy {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    GET /hello-proxy
--- response_body
hello earth
--- response_headers
ETag: "e5e0da9cf469b4842019c15e3ca531d1"



=== TEST 3: conditional get
--- config
    location = /hello {
        return 200 "hello world\n";
    }
    location = /hello-proxy {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- error_code: 304
--- request
    GET /hello-proxy
--- more_headers
If-None-Match: "6f5902ac237024bdd0c176cb93063dc4"
--- response_body



=== TEST 4: etag with proxy_pass + proxy_buffering
--- config
    location = /hello {
        return 200 "hello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earth\n";
    }
    location = /hello-proxy {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_buffering off;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    GET /hello-proxy
--- response_headers
ETag: "0ada7fc2e9c81a3699a0ab65bea60f54"



=== TEST 5: etag with head absent as we have no data to play with
--- config
    location = /hello {
        return 200 "hello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earthhello earth2\n";
    }
    location = /hello-proxy {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_buffering off;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    HEAD /hello-proxy
--- response_headers
!ETag



=== TEST 6: etag simple
--- config
    location = /hello {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        return 200 "hello world\n";
    }
--- request
    GET /hello
--- response_headers
ETag: "6f5902ac237024bdd0c176cb93063dc4"