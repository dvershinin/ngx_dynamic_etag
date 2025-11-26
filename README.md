# ngx_dynamic_etag

[![Build Status](https://travis-ci.org/dvershinin/ngx_dynamic_etag.svg?branch=master)](https://travis-ci.org/dvershinin/ngx_dynamic_etag)
[![Coverity Scan](https://img.shields.io/coverity/scan/dvershinin-ngx_dynamic_etag)](https://scan.coverity.com/projects/dvershinin-ngx_dynamic_etag)
[![Buy Me a Coffee](https://img.shields.io/badge/dynamic/json?color=blue&label=Buy%20me%20a%20Coffee&prefix=%23&query=next_time_total&url=https%3A%2F%2Fwww.getpagespeed.com%2Fbuymeacoffee.json&logo=buymeacoffee)](https://www.buymeacoffee.com/dvershinin)

This NGINX module empowers your dynamic content with automatic [`ETag`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
header. It allows client browsers to issue conditional `GET` requests to 
dynamic pages. And thus saves bandwidth and ensures better performance! 

## Caveats first!

This module is a real hack: it calls a header filter from a body filter, etc. It works, but in its current form, *not* production-ready.

See "Technical Limitations" at the bottom of this page.

Note that the `HEAD` requests will not have any `ETag` returned, because we have no data to play with, 
since NGINX rightfully discards body for this request method.

Consider this as a feature or a bug :-) If we remove this, then all `HEAD` requests end up having same `ETag` (hash on emptiness),
which is definitely worse.

Thus, be sure you check headers like this:

```bash
curl -IL -X GET https://www.example.com/
```
    
 And not like this:

 ```bash
curl -IL https://www.example.com/
```
     
Another worthy thing to mention is that it makes little to no sense applying dynamic `ETag` on a page that changes on 
each reload. E.g. I found I wasn't using the dynamic `ETag` with benefits, because of `<?= antispambot(get_option('admin_email')) ?>`,
in my WordPress theme's `header.php`, since in this function:

> the selection is random and changes each time the function is called 

To quickly check if your page is changing on reload, use:

```bash
diff <(curl http://www.example.com") <(curl http://www.example.com")
```

Now that we're done with the "now you know" yada-yada, you can proceed with trying out this stuff :)    


## Synopsis

```nginx
http {
    server {
        location ~ \.php$ {
            dynamic_etag on;
            fastcgi_pass ...;
        }
    }
}
```

## Configuration directives

### `dynamic_etag`

- **syntax**: `dynamic_etag on|off|$var`
- **default**: `off`
- **context**: `http`, `server`, `location`

Enables or disables applying ETag automatically.

### `dynamic_etag_types`

- **syntax**: `dynamic_etag_types <mime_type> [..]`
- **default**: `text/html`
- **context**: `http`, `server`, `location`

Enables applying ETag automatically for the specified MIME types
in addition to `text/html`. The special value `*` matches any MIME type.
Responses with the `text/html` MIME type are always included.

### `dynamic_etag_strength`

- **syntax**: `dynamic_etag_strength strong|weak|$var`
- **default**: `strong`
- **context**: `http`, `server`, `location`

Controls whether generated ETags are strong or weak. Weak ETags are useful for
dynamic content where semantic equality should be considered even if the
bytes differ (e.g., timestamps, randomized attributes). When using `$var`, map
to values `strong` or `weak`.

Note: These directives are not valid in the `if` context. Prefer using `$var`
with `map` to achieve conditional behavior.

Example with `map`:

```nginx
map $arg_w $etag_strength {
    default strong;
    1       weak;
}

location /example {
    dynamic_etag on;
    dynamic_etag_types text/html;
    dynamic_etag_strength $etag_strength;
    proxy_pass http://backend;
}
```

## Installation for stable NGINX

Pre-compiled module packages are available for virtually any RHEL-based distro like Rocky Linux, AlmaLinux, etc.

### Any Ubuntu or Debian

`ngx_dynamic_etag` is part of the APT NGINX Extras collection, so you can install
it alongside [any modules](https://apt-nginx-extras.getpagespeed.com/modules/), 
including Brotli.

First, [set up the repository](https://apt-nginx-extras.getpagespeed.com/apt-setup/), then:

```bash
sudo apt-get update
sudo apt-get install nginx-module-dynamic-etag
```

### Any distro with `yum`

```
sudo yum -y install https://extras.getpagespeed.com/release-latest.rpm
sudo yum install nginx-module-dynamic-etag
```

### Any distro with `dnf`

```bash
sudo dnf -y install https://extras.getpagespeed.com/release-latest.rpm
sudo dnf install nginx-module-dynamic-etag
```

Follow the installation prompt to import GPG public key that is used for verifying packages.

Then add the following at the top of your `/etc/nginx/nginx.conf`:

```nginx
load_module modules/ngx_http_dynamic_etag_module.so;
```

## Tips

You can use `map` directive for conditionally enabling dynamic `ETag` based on URLs, e.g.:

```nginx
map $request_uri $dyn_etag {
    default "off";
    /foo "on";
    /bar "on";
}
server { 
   ...
   location / {
       dynamic_etag $dyn_etag;
       fastcgi_pass ...
   }
}       
```        


## Technical Limitations (Code Review 2025)

A review of the source code (v1.26.x era) reveals significant design flaws that make this module unsuitable for production in its current state:

1.  **Broken ETag for Streamed Responses**:
    The module initializes a new MD5 context for every chunk of the response body (`ngx_http_dynamic_etag_body_filter`). It hashes only the first chunk, generates an ETag, and sends headers. Subsequent chunks are ignored for hashing purposes. This means:
    -   Large responses (spanning multiple buffers) get an ETag based solely on the first buffer.
    -   Files differing only after the first buffer will receive identical ETags (collisions).

2.  **Blocking I/O in Event Loop**:
    The code explicitly calls `ngx_read_file` (synchronous/blocking read) inside the body filter loop when handling file-backed buffers. This blocks the entire Nginx worker process during disk I/O, defeating Nginx's non-blocking architecture and potentially causing severe performance degradation under load.

3.  **Protocol & State Violations**:
    -   **Header Injection Timing**: The module attempts to hold back headers by returning `NGX_OK` in the header filter, then calls `ngx_http_next_header_filter` from within the *body filter*. This is architecturally incorrect and dangerous, as it violates the separation of header and body phases.
    -   **Multiple Header Sends**: For multi-chunk responses, the body filter code logic risks calling the next header filter multiple times.

4.  **Memory Inefficiency**:
    It sets `r->main_filter_need_in_memory = 1`, forcing Nginx to read potentially large responses into memory, increasing RAM usage significantly for serving files.

## TODO

To fix these issues, a complete rewrite of the filter logic is required:

-   [ ] **Implement Context-Aware Hashing**: Create a request module context to store the MD5 state (`ngx_md5_t`) across multiple body filter calls. Initialize on the first call, update on subsequent calls, and finalize only when `last_buf` or `last_in_chain` is seen.
-   [ ] **Full Body Buffering**: Since ETag requires the *entire* content to be known before sending the header, the module must intercept and buffer the entire response body (similar to how the `upstream` module works or using a temporary file) before calculating the final hash and sending headers. *Note: This negate the benefits of streaming.*
-   [ ] **Remove Blocking I/O**: Rely on Nginx's internal buffer handling or asynchronous file operations instead of direct `ngx_read_file`.
-   [ ] **Fix Header Filter Logic**: Restore standard header filter behavior. If buffering is implemented, headers will naturally be delayed until the buffer is ready.
