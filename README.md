# ngx_dynamic_etag

[![Build Status](https://travis-ci.org/dvershinin/ngx_dynamic_etag.svg?branch=master)](https://travis-ci.org/dvershinin/ngx_dynamic_etag)
[![Coverity Scan](https://img.shields.io/coverity/scan/dvershinin-ngx_dynamic_etag)](https://scan.coverity.com/projects/dvershinin-ngx_dynamic_etag)

This NGINX module empowers your dynamic content with automatic [`ETag`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)
header. It allows client browsers to issue conditional `GET` requests to 
dynamic pages. And thus saves bandwidth and ensures better performance! 

## Caveats first!

This module is a real hack: it calls a header filter from a body filter, etc. 

The original author abandoned it, [having to say](https://github.com/kali/nginx-dynamic-etags/issues/2):
 
 > It never really worked.

I largely rewrote it to deal with existing obvious faults, but the key part with buffers, 
which, myself being old, I probably wil l never understand, is untouched.

To be reliable, the module has to read entire response and take a hash of it. 
Reading entire response is against NGINX lightweight design.
I am not sure whether the buffer part waits for the entire response.

Having said that, the tests which I added showcase that this whole stuff works!

Note that the `HEAD` requests will not have any `ETag` returned, because we have no data to play with, 
since NGINX rightfully discards body for this request method.

Consider this as a feature or a bug :-) If we remove this, then all `HEAD` requests end up having same `ETag` (hash on emptiness),
which is definitely worse.

Thus, be sure you check headers like this:

    curl -IL -X GET https://www.example.com/
    
 And not like this:
 
     curl -IL https://www.example.com/
     
Another worthy thing to mention is that it makes little to no sense applying dynamic `ETag` on a page that changes on 
each reload. E.g. I found I wasn't using the dynamic `ETag` with benefits, because of `<?= antispambot(get_option('admin_email')) ?>`,
in my Wordpress theme's `header.php`, since in this function:

> the selection is random and changes each time the function is called 

To quickly check if your page is changing on reload, use:

    diff <(curl http://www.example.com") <(curl http://www.example.com")

Now that we're done with the "now you know" yada-yada, you can proceed with trying out this stuff :)    


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

### CentOS/RHEL 6, 7, 8

    sudo yum -y install https://extras.getpagespeed.com/release-latest.rpm
    sudo yum install nginx-module-dynamic-etag

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
