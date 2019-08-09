# ngx_dynamic_etag

This NGINX module empowers your dynamic content with automatic [`ETag`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
header. It allows client browsers to issue conditional `GET` requests to 
dynamic pages. And thus saves bandwidth and ensures better performance! 

## Synopsis

```
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
- **context**: `http`, `server`, `location`, `if`

Enables or disables applying ETag automatically.

### `dynamic_etag_types`

- **syntax**: `dynamic_etag_types <mime_type> [..]`
- **default**: `text/html`
- **context**: `http`, `server`, `location`

Enables applying ETag automatically for the specified MIME types
in addition to `text/html`. The special value `*` matches any MIME type.
Responses with the `text/html` MIME type are always included.

## Installation for stable NGINX

### RHEL/CentOS 6/7

    yum install https://extras.getpagespeed.com/release-el$(rpm -E %{rhel})-latest.rpm
    yum install nginx nginx-module-dynamic-etag

Follow the installation prompt to import GPG public key that is used for verifying packages.

Then add the following at the top of your `/etc/nginx/nginx.conf`:

    load_module modules/ngx_http_dynamic_etag_module.so;

## Tips

You can use `map` directive for conditionally enabling dynamic `ETag` based on URLs, e.g.:

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
        

## Original author's README

Attempt at handling ETag / If-None-Match on proxied content.

I plan on using this to front a Varnish server using a lot of ESI.

It does kind of work, but... be aware, this is my first attempt at developing
a nginx plugin, and dealing with headers after having read the body was not
exactly in the how-to.

Any comment and/or improvement and/or fork is welcome.

Thanks to http://github.com/kkung/nginx-static-etags/ for... inspiration.
