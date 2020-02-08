## Getting tests suite to work in RHEL 8

Files layout:

* `~/Projects/nginx-stable` - NGINX core sources
* `~/Projects/nginx-stable/ngx_dynamic_etag` - the module sources
* `~/nginx-stable` - compiled NGINX files installed here for testing

Setup test framework:

    sudo dnf install perl-App-cpanminus perl-local-lib
    # now CPAN modules can be installed as non-root: 
    cpanm Test::Nginx::Socket
    
Then read what you need to add to `~/.bashrc` by running `perl -Mlocal::lib`, and add it, e.g.:

```
PATH="/home/danila/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/danila/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/danila/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/danila/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/danila/perl5"; export PERL_MM_OPT;
```

For testing, the module needs to be compiled in statically:

    ./configure --prefix=${HOME}/nginx-stable --add-module=../ngx_dynamic_etag --with-http_ssl_module

... and nginx available to your `PATH`. Considering that `.local/bin` is in your `PATH` (typical Python user), 
you can symlink compiled `nginx` binary in that directory:

```bash
cd ~/.local/bin
ln -fs ${HOME}/Projects/nginx-stable/objs/nginx ./nginx
```

* [Running Tests](https://openresty.gitbooks.io/programming-openresty/content/testing/running-tests.html)
* [ngx-releng utility](https://github.com/openresty/openresty-devel-utils/blob/master/ngx-releng)
* [tests reindex](https://github.com/openresty/openresty-devel-utils/blob/master/reindex)