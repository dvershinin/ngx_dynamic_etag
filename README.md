# ngx_dynamic_etag

This NGINX module allows to empower your dynamic content with automatic `ETag`
header. This allows client browser to issue conditional `GET` requests to 
dynamic pages. And thus saves bandwidth and ensures better performance! 

## Configuration directives

### `dynamic_etag`

- **syntax**: `dynamic_etag on|off`
- **default**: `off`
- **context**: `http`, `server`, `location`, `if`

Enables or disables applying ETag automatically.

### `dynamic_etag_types`

- **syntax**: `dynamic_etag_types <mime_type> [..]`
- **default**: `text/html`
- **context**: `http`, `server`, `location`

Enables applying ETag automatically for the specified MIME types
in addition to `text/html`. The special value `*` matches any MIME type.
Responses with the `text/html` MIME type are always included.

## TODOs

* Look into implementing [If-Match](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)

## Original author's README

Attempt at handling ETag / If-None-Match on proxied content.

I plan on using this to front a Varnish server using a lot of ESI.

It does kind of work, but... be aware, this is my first attempt at developping
a nginx plugin, and dealing with headers after having read the body was not
exactly in the how-to.

Any comment and/or improvement and/or fork is welcome.

Thanks to http://github.com/kkung/nginx-static-etags/ for... inspiration.
