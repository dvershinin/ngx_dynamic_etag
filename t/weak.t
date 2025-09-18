use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: weak ETag with directive
--- config
    location = /hello {
        return 200 "hello world\n";
    }
    location = /weak-directive {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        dynamic_etag_strength weak;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    GET /weak-directive
--- response_body
hello world
--- response_headers
ETag: W/"6f5902ac237024bdd0c176cb93063dc4"



=== TEST 2: weak/strong via mapped variable
--- http_config
    map $arg_w $etag_strength {
        default strong;
        1       weak;
    }
--- config
    location = /hello {
        return 200 "hello world\n";
    }
    location = /weak-map {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        dynamic_etag_strength $etag_strength;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/hello;
    }
--- request
    GET /weak-map
--- response_body
hello world
--- response_headers
ETag: "6f5902ac237024bdd0c176cb93063dc4"
--- request
    GET /weak-map?w=1
--- response_body
hello world
--- response_headers
ETag: W/"6f5902ac237024bdd0c176cb93063dc4"


