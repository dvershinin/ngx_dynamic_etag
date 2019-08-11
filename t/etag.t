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


=== TEST 2: conditional get
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
