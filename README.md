# ngx_dynamic_etag

[![Build Status](https://travis-ci.org/dvershinin/ngx_dynamic_etag.svg?branch=master)](https://travis-ci.org/dvershinin/ngx_dynamic_etag)
[![Coverity Scan](https://img.shields.io/coverity/scan/dvershinin-ngx_dynamic_etag)](https://scan.coverity.com/projects/dvershinin-ngx_dynamic_etag)
[![Buy Me a Coffee](https://img.shields.io/badge/dynamic/json?color=blue&label=Buy%20me%20a%20Coffee&prefix=%23&query=next_time_total&url=https%3A%2F%2Fwww.getpagespeed.com%2Fbuymeacoffee.json&logo=buymeacoffee)](https://www.buymeacoffee.com/dvershinin)

This NGINX module empowers your dynamic content with automatic [`ETag`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
header. It allows client browsers to issue conditional `GET` requests to 
dynamic pages. And thus saves bandwidth and ensures better performance! 

## Production Usage

This module is suitable for production with the following considerations:

### Important: Configure Adequate Proxy Buffers

For correct ETags, ensure your `proxy_buffers` are large enough to hold typical responses:

```nginx
# Recommended: Buffer up to 256KB responses
proxy_buffer_size 64k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
```

If responses exceed buffer capacity, only the first chunk is hashed, which may cause
ETag collisions for files with identical prefixes. See [Technical Limitations](#technical-limitations).

### Things to Know

**HEAD requests**: No `ETag` is returned for HEAD requests since there's no body to hash.
This is intentional—otherwise all HEAD requests would get identical ETags.

When testing, use:

```bash
curl -IL -X GET https://www.example.com/
```

Not:

```bash
curl -IL https://www.example.com/
```

**Dynamic content**: This module works best when content is deterministic. If your page
changes on every reload (e.g., random tokens, timestamps), the ETag will change too,
defeating the caching benefit.

To check if your page content is stable:

```bash
diff <(curl -s http://www.example.com/) <(curl -s http://www.example.com/)
```    


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


## Technical Limitations

These are known limitations to be aware of when using this module in production.

### Buffer Size and ETag Accuracy

The module hashes content that arrives in the **first** body filter call:

| Scenario | Result |
|----------|--------|
| Response fits in `proxy_buffers` | ✅ Correct ETag (full content hashed) |
| Response exceeds `proxy_buffers` | ⚠️ Partial ETag (only first chunk hashed) |
| `proxy_buffering off` | ⚠️ Partial ETag (only first chunk hashed) |

**For correct ETags**, configure buffers larger than your typical responses:

```nginx
# Buffer responses up to 256KB
proxy_buffer_size 64k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
```

### What Partial Hashing Means (Important!)

When only a partial ETag is generated, **clients may receive stale content**:

1. Client requests `/page` → receives content with ETag based on first chunk
2. Content changes, but only **after** the first chunk (e.g., footer update)
3. Client sends `If-None-Match` with the old ETag
4. Server sees the first chunk is unchanged → returns `304 Not Modified`
5. **Client displays stale content** because it trusts the 304 response

This is why adequate buffer sizing is critical. If you cannot guarantee buffers
are large enough for all responses, consider:

- Disabling dynamic ETags for large/variable responses
- Using weak ETags (`dynamic_etag_strength weak`) to signal semantic equivalence only

### Other Considerations

1. **Memory Usage**: The module loads response content into memory to compute the MD5 hash.
   For very large responses, ensure adequate RAM.

2. **File-Backed Buffers**: Synchronous file reads are used for file-backed buffers,
   which may briefly block the worker process during disk I/O.

3. **Header Timing**: Headers are delayed until the body filter runs to calculate the ETag.
   This is architecturally unusual but necessary for the module to function.
