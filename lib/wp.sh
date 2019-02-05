##
# KUSANAGI WordPres Deployment for kusanagi-docker
# (C)2019 Prime-Strategy Co,Ltd
# Licenced by GNU GPL v2
#

source .kusanagi
source .kusanagi.wp
source $KUSANAGILIBDIR/.version

IMAGE=$([ $OPT_NGINX ] && echo $KUSANAGI_NGINX_IMAGE || [ $OPT_HTTPD ] && echo $KUSANGI_HTTPD_IMAGE)
# create docker-compose.yml
env PROFILE=$PROFILE \
    KUSANAGI_HTTPD_IMAGE=$IMAGE \
    KUSANAGI_PHP7_IMAGE=$KUSANAGI_PHP7_IMAGE \
    WPCLI_IMAGE=$WPCLI_IMAGE \
    CERTBOT_IMAGE=$CERTBOT_IMAGE \
	envsubst "$$PROFILE $$HTTPD_IMAGE
	$$KUSANAGI_PHP7_IMAGE $$KUSANAGI_FTPD_IMAGE
	$$WPCLI_IMAGE $$CERTBOT_IMAGE" \
	< <(cat $LIBDIR/templates/docker.template $LIBDIR/templates/wpcli.template) > docker-compose.yml
if [[ $DBHOST =~ "^localhost:" ]] ; then
	env PROFILE=$PROFILE KUSANAGI_MARIADB_IMAGE=$KUSANAGI_MARIADB_IMAGE \
	envsubst "$$PROFILE $$KUSANAGI_MARIADB_IMAGE" \
	< $LIBDIR/templates/mariadb.template >> docker-compose.yml
fi
if ! [ $NO_USE_FTP ] ; then
    env PROFILE=$PROFILE KUSANAGI_FTPD_IMAGE=$KUSANAGI_FTPD_IMAGE  \
	envsubst "$$PROFILE $$KUSANAGI_FTP_IMAGE" \
	< $LIBDIR/templates/ftpd.template >> docker-compose.yml
fi
echo >> docker-compose.yml
echo 'volumes:' >> docker-compose.yml
echo '  kusanagi:' >>  docker-compose.yml
[[ $DBHOST =~ "^localhost:" ]] && echo '  database:' >>  docker-compose.yml


docker-compose up -d \
&& docker-compose --rm run wpcli mkdir -p $DOCUMENTROOT \
&& docker-compose --rm run wpcli core download --path=${DOCUMENTROOT} \
	${WP_LANG:+ --locale=$WP_LANG} \
&& docker-compose--rm  run wpcli core config --path=${DOCUMENTROOT} \
	--dbname=${DBNAME} --dbuser=${DBUSER} --dbpass=${DBPASS} \
	${DBPREFIX:+--dbprefix $DBPREFIX} \
	--dbcharset=${MYSQL_CHARSET:-utf8mb4} --extra-php < $LIBDIR/wp/wp-config-extra.php \
&& docker-compose run--rm  wpcli core install --path=$DOCUMENTROOT --url=http://${FQDN} \
	--title=${WP_TITLE} --admin_user=${ADMIN_USER} \
	--admin_password=${ADMIN_PASSWORD} --admin_email=${ADMIN_EMAIL} \
&& tar cf - -C $LIBDIR/wp mu-plugins | docker-compose run --rm wpcli tar xf - -C $DOCUMENTROOT/wp-content/ \
&& tar cf - -C $LIBDIR/wp tools settings | docker-compose run --rm wpcli tar xf - -C $DOCUMENTROOT/ \
&& docker-compose run wpcli --rm mkdir -p $DOCUMENTROOT/wp-content/languages \
&& docker-compose run wpcli --rm chmod 0777 $DOCUMENTROOT $DOCUMENTROOT/wp-content $DOCUMENTROOT/wp-content/uploads \
&& docker-compose run wpcli --rm chmod -R 0777 $DOCUMENTROOT $DOCUMENTROOT/wp-content/languages $DOCUMENTROOT/wp-content/plugins \
&& docker-compose run wpcli --rm sed -i "s/fqdn/$FQDN/g" $DOCUMENTROOT/tools/bcache.clear.php || return 1

#if [ $OPT_WOO ] ; then
#	docker-compose --rm run wpcli theme install storefront
#	docker cp $PROFILE_httpd $KUSANAGILIBDIR/wp/wc4jp-gmo-pg.1.2.0.zip $PROFILE_httpd:$DOCUMENTROOT
#	docker-compose --rm run wpcli unzip -q -d $DOCUMENTROOT/wp-content/plugins $DOCUMENTROOT/wc4jp-gmo-pg.1.2.0.zip
#	docker-compose --rm run wpcli rm $DOCUMENTROOT/wc4jp-gmo-pg.1.2.0.zip
#	if [ "WPLANG" = "ja" ] ; then
#		docker-compose --rm run wpcli plugin install woocommerce-for-japan
#		docker-compose --rm run wpcli language plugin install woocommerce-for-japan ja
#		docker-compose --rm run wpcli language theme install storefront ja
#		docker-compose --rm run wpcli plugin activate woocommerce-for-japan
#	fi
#	docker-compose --rm run wpcli theme activate storefront
#	docker-compose --rm run wpcli plugin activate wc4jp-gmo-pg
#
#fi

