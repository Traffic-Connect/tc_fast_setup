; TC Custom
; v 1.00
;

[%backend%]
listen = /run/php/php%backend_version%-fpm-%domain%.sock
listen.owner = %user%
listen.group = www-data
listen.mode = 0660

user = %user%
group = %user%

pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 15
pm.max_requests = 2000
pm.process_idle_timeout = 10s
pm.status_path = /status

request_terminate_timeout = 30s
request_slowlog_timeout = 5s

slowlog = /var/log/php-fpm-slow.log

php_admin_value[upload_tmp_dir] = /home/%user%/tmp
php_admin_value[session.save_path] = /home/%user%/tmp
php_admin_value[open_basedir] = /home/%user%/.composer:/home/%user%/web/%domain%/public_html:/home/%user%/web/%domain%/private:/home/%user%/web/%domain%/public_shtml:/home/%user%/tmp:/tmp:/bin:/usr/bin:/usr/local/bin:/usr/share:/opt
php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f admin@%domain%

php_admin_value[opcache.enable] = 1
php_admin_value[opcache.enable_cli] = 1
php_admin_value[opcache.memory_consumption] = 512
php_admin_value[opcache.interned_strings_buffer] = 32
php_admin_value[opcache.max_accelerated_files] = 20000
php_admin_value[opcache.revalidate_freq] = 120
php_admin_value[opcache.validate_timestamps] = 1

env[HOSTNAME] = %HOSTNAME%
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /home/%user%/tmp
env[TMPDIR] = /home/%user%/tmp
env[TEMP] = /home/%user%/tmp
