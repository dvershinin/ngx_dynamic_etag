use Test::Nginx::Socket 'no_plan';

# Self-contained: these blocks proxy to a fake backend, and the port is
# substituted into `--- config` from the environment. Default it here so a
# bare `prove` (which is what CI runs) does not bail out.
$ENV{TEST_NGINX_BACKEND_PORT} ||= 19851;

no_shuffle();
no_root_location();

# Pre-generate content for use in tests
# file_a: 5KB of 'A' followed by 5KB of 'B' = 10KB total
# file_b: 5KB of 'A' followed by 5KB of 'C' = 10KB total (same prefix, different suffix)
our $a_prefix = "A" x 5120;  # 5KB of A
our $a_suffix = "B" x 5120;  # 5KB of B  
our $b_suffix = "C" x 5120;  # 5KB of C
our $file_a_content = $a_prefix . $a_suffix;
our $file_b_content = $a_prefix . $b_suffix;

# Expected hashes:
# - Full file_a: 7159a50047a602beb40c4707db0fe997
# - Full file_b: af1f167c3c94e71c95d7e54199fb6dfe

run_tests();

__DATA__

=== TEST 1: With buffering on, module hashes full content correctly
When buffering is enabled, all data arrives in a single body filter call.
File_a should get its correct full-content ETag.

--- http_config
    proxy_buffer_size 16k;
    proxy_buffers 4 16k;
    proxy_busy_buffers_size 32k;

--- config
    location = /proxy_a {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_BACKEND_PORT/;
    }

--- tcp_listen eval: $ENV{TEST_NGINX_BACKEND_PORT} || 19851
--- tcp_reply eval
my $body = $main::file_a_content;
my $len = length($body);
"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: $len\r\nConnection: close\r\n\r\n$body"

--- request
GET /proxy_a

--- response_headers
ETag: "7159a50047a602beb40c4707db0fe997"

--- error_code: 200



=== TEST 2: With buffering on, file_b gets correct different ETag
--- http_config
    proxy_buffer_size 16k;
    proxy_buffers 4 16k;
    proxy_busy_buffers_size 32k;

--- config
    location = /proxy_b {
        dynamic_etag on;
        dynamic_etag_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_BACKEND_PORT/;
    }

--- tcp_listen eval: $ENV{TEST_NGINX_BACKEND_PORT} || 19851
--- tcp_reply eval
my $body = $main::file_b_content;
my $len = length($body);
"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: $len\r\nConnection: close\r\n\r\n$body"

--- request
GET /proxy_b

--- response_headers
ETag: "af1f167c3c94e71c95d7e54199fb6dfe"

--- error_code: 200
