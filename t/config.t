use Test::Nginx::Socket 'no_plan';

run_tests();

__DATA__

=== TEST 1: dying on bad config
--- http_config
    dynamic_etag bad;
--- config
--- must_die
--- error_log
directive should be either on, off, or a $variable