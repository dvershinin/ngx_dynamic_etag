/*
 * Copyright (c) 2019 Danila Vershinin ( https://www.getpagespeed.com/ )
 * Copyright (c) 2009 Mathieu Poumeyrol ( http://github.com/kali )
 *
 * All rights reserved.
 * All original code was written by Mike West ( http://mikewest.org/ ) and
       Adrian Jung ( http://me2day.net/kkung, kkungkkung@gmail.com ).
 *
 * Copyright 2008 Mike West ( http://mikewest.org/ )
 * Copyright 2009 Adrian Jung ( http://me2day.net/kkung, kkungkkung@gmail.com ).
 *
 * The following is released under the Creative Commons BSD license,
 * available for your perusal at `http://creativecommons.org/licenses/BSD/`
 */
#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <ngx_md5.h>

typedef struct {
    ngx_uint_t   enable;
    ngx_http_complex_value_t enable_value;
    ngx_hash_t   types;
    ngx_array_t  *types_keys;
} ngx_http_dynamic_etag_loc_conf_t;

typedef struct {
    ngx_flag_t done;
} ngx_http_dynamic_etag_module_ctx_t;

static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;
static ngx_http_output_body_filter_pt    ngx_http_next_body_filter;

static void *ngx_http_dynamic_etag_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_dynamic_etag_merge_loc_conf(ngx_conf_t *cf, void *parent,
    void *child);
static ngx_int_t ngx_http_dynamic_etag_init(ngx_conf_t *cf);
static ngx_int_t ngx_http_dynamic_etag_header_filter(ngx_http_request_t *r);
static ngx_int_t ngx_http_dynamic_etag_body_filter(ngx_http_request_t *r,
    ngx_chain_t *in);
static char *ngx_http_dynamic_etag_enable(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);

static ngx_command_t  ngx_http_dynamic_etag_commands[] = {

    { ngx_string( "dynamic_etag" ),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_http_dynamic_etag_enable,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

     { ngx_string("dynamic_etag_types"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_1MORE,
      ngx_http_types_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_dynamic_etag_loc_conf_t, types_keys),
      &ngx_http_html_default_types[0] },

      ngx_null_command
};



static ngx_http_module_t  ngx_http_dynamic_etag_module_ctx = {
    NULL,                                   /* preconfiguration */
    ngx_http_dynamic_etag_init,             /* postconfiguration */

    NULL,                                   /* create main configuration */
    NULL,                                   /* init main configuration */

    NULL,                                   /* create server configuration */
    NULL,                                   /* merge server configuration */

    ngx_http_dynamic_etag_create_loc_conf,  /* create location configuration */
    ngx_http_dynamic_etag_merge_loc_conf,   /* merge location configuration */
};

ngx_module_t  ngx_http_dynamic_etag_module = {
    NGX_MODULE_V1,
    &ngx_http_dynamic_etag_module_ctx,  /* module context */
    ngx_http_dynamic_etag_commands,     /* module directives */
    NGX_HTTP_MODULE,                    /* module type */
    NULL,                               /* init master */
    NULL,                               /* init module */
    NULL,                               /* init process */
    NULL,                               /* init thread */
    NULL,                               /* exit thread */
    NULL,                               /* exit process */
    NULL,                               /* exit master */
    NGX_MODULE_V1_PADDING
};

static void *
ngx_http_dynamic_etag_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_dynamic_etag_loc_conf_t    *conf;

    conf = ngx_pcalloc( cf->pool, sizeof( ngx_http_dynamic_etag_loc_conf_t ) );
    if (conf == NULL) {
        return NGX_CONF_ERROR;
    }
    /*
     * set by ngx_pcalloc():
     *
     *     conf->types = { NULL };
     *     conf->types_keys = NULL;
     */
    conf->enable = NGX_CONF_UNSET_UINT;
    return conf;
}

static char *
ngx_http_dynamic_etag_merge_loc_conf(ngx_conf_t *cf, void *parent,
    void *child)
{
    ngx_http_dynamic_etag_loc_conf_t *prev = parent;
    ngx_http_dynamic_etag_loc_conf_t *conf = child;

    if (conf->enable == NGX_CONF_UNSET_UINT) {
        ngx_conf_merge_uint_value(conf->enable, prev->enable, 0);
        conf->enable_value = prev->enable_value;
    }

    if (ngx_http_merge_types(cf, &conf->types_keys, &conf->types,
                             &prev->types_keys, &prev->types,
                             ngx_http_html_default_types)
        != NGX_OK)
    {
        return NGX_CONF_ERROR;
    }

    return NGX_CONF_OK;
}

static ngx_int_t
ngx_http_dynamic_etag_init(ngx_conf_t *cf)
{
    ngx_http_next_header_filter = ngx_http_top_header_filter;
    ngx_http_top_header_filter = ngx_http_dynamic_etag_header_filter;

    ngx_http_next_body_filter = ngx_http_top_body_filter;
    ngx_http_top_body_filter = ngx_http_dynamic_etag_body_filter;

    return NGX_OK;
}

static ngx_int_t
ngx_http_dynamic_etag_header_filter(ngx_http_request_t *r)
{

    ngx_http_dynamic_etag_module_ctx_t  *ctx;
    ngx_http_dynamic_etag_loc_conf_t    *conf;
    ngx_str_t                            enable;


    conf = ngx_http_get_module_loc_conf(r, ngx_http_dynamic_etag_module);

    if (conf->enable == 0 || r->method & NGX_HTTP_HEAD) {
        return ngx_http_next_header_filter(r);
    } else if (conf->enable == 2) {
        if (ngx_http_complex_value(r, &conf->enable_value, &enable) != NGX_OK) {
            return NGX_ERROR;
        }
        if (enable.len == 3
            && ngx_strncmp(enable.data, "off", 3) == 0)
        {
            return ngx_http_next_header_filter(r);
        }
    }

    if (r->headers_out.status != NGX_HTTP_OK
        || ngx_http_test_content_type(r, &conf->types) == NULL
        || r != r->main)
    {
        return ngx_http_next_header_filter(r);
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_dynamic_etag_module);

    if (ctx) {
        return ngx_http_next_header_filter(r);
    }

    ctx = ngx_pcalloc(r->pool, sizeof(ngx_http_dynamic_etag_module_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }

    ngx_http_set_ctx(r, ctx, ngx_http_dynamic_etag_module);

    r->main_filter_need_in_memory = 1;
    r->filter_need_in_memory = 1;

    /* Make sure that ngx_http_not_modified_filter_module does its stuff */
    r->disable_not_modified = 0;

    return NGX_OK;
}

static u_char hex[] = "0123456789abcdef";

static ngx_int_t
ngx_http_dynamic_etag_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_chain_t                         *chain_link;
    ngx_http_dynamic_etag_module_ctx_t  *ctx;

    ngx_int_t      rc;
    ngx_md5_t      md5;
    unsigned char  digest[16];
    ngx_uint_t     i;

    ctx = ngx_http_get_module_ctx(r, ngx_http_dynamic_etag_module);
    if (ctx == NULL) {
        return ngx_http_next_body_filter(r, in);
    }

    ngx_http_dynamic_etag_loc_conf_t  *conf;
    ngx_str_t   enable;

    conf = ngx_http_get_module_loc_conf(r, ngx_http_dynamic_etag_module);


    if (conf->enable == 2) {
        if (ngx_http_complex_value(r, &conf->enable_value, &enable)
            != NGX_OK)
        {
            return NGX_ERROR;
        }
    }


    if (1 == conf->enable
        || (conf->enable == 2 && enable.len == 2
        && ngx_strncmp(enable.data, "on", 2) == 0))
    {
        if (!r->headers_out.etag) {
            ngx_md5_init(&md5);
            for (chain_link = in; chain_link; chain_link = chain_link->next) {
                ngx_md5_update(&md5,
                               chain_link->buf->pos,
                          chain_link->buf->last - chain_link->buf->pos);
            }
            ngx_md5_final(digest, &md5);

            unsigned char * etag = ngx_pcalloc(r->pool, 34);
            if (etag == NULL) {
                return NGX_ERROR;
            }
            etag[0] = etag[33] = '"';
            for ( i = 0 ; i < 16; i++ ) {
                etag[2 * i + 1] = hex[digest[i] >> 4];
                etag[2 * i + 2] = hex[digest[i] & 0xf];
            }

            r->headers_out.etag = ngx_list_push(&r->headers_out.headers);
            if (r->headers_out.etag == NULL) {
                return NGX_ERROR;
            }
            r->headers_out.etag->hash = 1;
            r->headers_out.etag->key.len = sizeof("ETag") - 1;
            r->headers_out.etag->key.data = (u_char *) "ETag";
            r->headers_out.etag->value.len = 34;
            r->headers_out.etag->value.data = etag;
        }
    }


    rc = ngx_http_next_header_filter(r);
    if (rc == NGX_ERROR || rc > NGX_OK) {
        return NGX_ERROR;
    }

    ngx_http_set_ctx(r, NULL, ngx_http_dynamic_etag_module);

    return ngx_http_next_body_filter(r, in);
}

static char *
ngx_http_dynamic_etag_enable(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_dynamic_etag_loc_conf_t *clcf = conf;

    ngx_str_t                         *value;
    ngx_http_compile_complex_value_t   ccv;

    if (clcf->enable != NGX_CONF_UNSET_UINT) {
        return "is duplicate";
    }

    value = cf->args->elts;

    if (ngx_strcmp(value[1].data, "on") == 0) {
        clcf->enable = 1;
        return NGX_CONF_OK;
    } else if (ngx_strcmp(value[1].data, "off") == 0) {
        clcf->enable = 0;
        return NGX_CONF_OK;
    } else if (ngx_strncmp(value[1].data, "$", 1) != 0) {
        return "should be either on, off, or a $variable";
    }

    ngx_memzero(&ccv, sizeof(ngx_http_compile_complex_value_t));

    ccv.cf = cf;
    ccv.value = &value[1];
    ccv.complex_value = &clcf->enable_value;

    if (ngx_http_compile_complex_value(&ccv) != NGX_OK) {
        return NGX_CONF_ERROR;
    }

    /* variable */
    clcf->enable = 2;

    return NGX_CONF_OK;
}