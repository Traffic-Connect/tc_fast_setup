#
# TC Nginx+Apache
# v 1.01
#

server {
	listen      %ip%:%proxy_port%;
	server_name %domain_idn% %alias_idn%;
	error_log   /var/log/%web_system%/domains/%domain%.error.log error;

	include %home%/%user%/conf/web/%domain%/nginx.forcessl.conf*;

	location = /favicon.ico {
		log_not_found off;
		access_log off;
	}

	location ~ /\.(?!well-known\/|file) {
		deny all;
		return 404;
	}

	location ~ ^/wp-content/cache { deny all; }

	location / {
		proxy_pass https://%ip%:%web_ssl_port%;

		location ~* ^.+\.(ogg|ogv|svg|svgz|swf|eot|otf|woff|woff2|mov|mp3|mp4|webm|flv|ttf|rss|atom|jpg|jpeg|gif|png|webp|ico|bmp|mid|midi|wav|rtf|css|js|jar|json|cur|3gp|av1|avi|doc|docx|pdf|txt|xls|xlsx|apk)$ {
			try_files $uri =404;

			root       %sdocroot%;
			access_log /var/log/nginx/domains/%domain%.log combined;
			access_log /var/log/nginx/domains/%domain%.bytes bytes;

			expires    max;
		}

		location ~* /(?:uploads|files)/.*.php$ {
			deny all;
			return 404;
		}

	}

	location /error/ {
	      alias %home%/%user%/web/%domain%/document_errors/;
	}

	location ~* (debug\.log|readme\.html|license\.txt|xmlrpc\.php|nginx\.conf)$ {
		return 404;
	}

	location /wthme/ {
		rewrite ^/wthme/(.*)$ /wp-content/plugins/hb_waf/themes/$1 last;
	}

	proxy_hide_header Upgrade;

	include %home%/%user%/conf/web/%domain%/nginx.conf_*;
	include %sdocroot%/ngin*.conf;
}
