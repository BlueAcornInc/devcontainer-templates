#!/bin/bash

echo "Starting commerce.sh"

function configure_base_url () {
    local base_url=$1
    local use_secure=$2

    bin/magento config:set --lock-env web/unsecure/base_url "$base_url"
    bin/magento config:set --lock-env web/secure/base_url "$base_url"

    bin/magento config:set --lock-env web/secure/use_in_frontend "$use_secure"
    bin/magento config:set --lock-env web/secure/use_in_adminhtml "$use_secure"

    if [ -n "$CODESPACE_NAME" ]; then
        bin/magento config:set --lock-env web/url/redirect_to_base 0
    fi
}

set -e

: ${PHP_MODE:="builtin"}
: ${DEPLOY_MODE:="developer"}
: ${INSTALL_SAMPLE_DATA:="false"}
: ${COMMERCE_EDITION:="magento/project-enterprise-edition"}
: ${SKIP_SETUP:="false"}

if [ "$PHP_MODE" == "builtin" ]; then
    : ${PORT:=8080}
    : ${USE_SECURE_URL:="0"}
    : ${PROTOCOL:="http"}
else
    : ${USE_SECURE_URL:="1"}
    : ${PORT:=8443}
    : ${PROTOCOL:="https"}
fi

: ${BASEURL:="$PROTOCOL://localhost:$PORT/"}

if [ -n "$CODESPACE_NAME" ]; then
    PORT=80
    BASEURL="https://$CODESPACE_NAME-$PORT.app.github.dev/"
    USE_SECURE_URL="0"
    echo "Setting base URL to $BASEURL"
fi

if [ "$SKIP_SETUP" != "true" ]
then


    if [ ! -f composer.auth ]; then

        composer create-project --repository-url=https://repo.magento.com/ $COMMERCE_EDITION ./tmp
        mv -r tmp/** .
    else
    composer install
    fi

    if [ -n "$COMPOSER_REQUIRES" ]; then
        composer require $COMPOSER_REQUIRES
    fi

    composer install

    if [ ! -f app/etc/env.php ]
        then

        INSTALL="true"
        bin/magento setup:install \
            --backend-frontname=backend \
            --amqp-host=127.0.0.1 \
            --amqp-port=5672 \
            --amqp-user=guest \
            --amqp-password=guest \
            --db-host=127.0.0.1 \
            --db-user=magento \
            --db-password=magento \
            --db-name=magento \
            --search-engine=opensearch \
            --opensearch-host=127.0.0.1 \
            --opensearch-port=9200 \
            --opensearch-index-prefix=magento2 \
            --opensearch-enable-auth=1 \
            --opensearch-username=admin \
            --opensearch-password=fhgLpkH66PwD \
            --opensearch-timeout=15 \
            --session-save=redis \
            --session-save-redis-host=127.0.0.1 \
            --session-save-redis-port=6379 \
            --session-save-redis-db=2 \
            --session-save-redis-max-concurrency=20 \
            --cache-backend=redis \
            --cache-backend-redis-server=127.0.0.1 \
            --cache-backend-redis-db=0 \
            --cache-backend-redis-port=6379 \
            --page-cache=redis \
            --page-cache-redis-server=127.0.0.1 \
            --page-cache-redis-db=1 \
            --page-cache-redis-port=6379


        bin/magento config:set --lock-env web/seo/use_rewrites 1
        bin/magento config:set --lock-env system/full_page_cache/caching_application 1
        bin/magento config:set --lock-env system/full_page_cache/ttl 604800
        bin/magento config:set --lock-env catalog/search/enable_eav_indexer 1
        bin/magento config:set --lock-env dev/static/sign 0

        if [ "$ENABLE_IMS" == "true" ]; then
            bin/magento admin:adobe-ims:enable \
                --organization-id=$IMS_ORG_ID \
                --client-id=$IMS_CLIENT_ID \
                --client-secret=$IMS_CLIENT_SECRET \
                --2fa=$IMS_2FA_ENABLED
        else
            bin/magento module:disable Magento_AdminAdobeImsTwoFactorAuth Magento_TwoFactorAuth
        fi

        bin/magento cache:enable block_html full_page

        bin/magento admin:user:create --admin-user admin --admin-password admin123 --admin-firstname demo --admin-lastname user --admin-email noreply@blueacornici.com

        if [ -n "$POST_INSTALL_CMD" ]; then
            eval "$POST_INSTALL_CMD"
        fi

        configure_base_url $BASEURL $USE_SECURE_URL

        if [ -n "$CODESPACE_NAME" ]; then
            bin/magento config:set --lock-env web/url/redirect_to_base 0
        fi

        bin/magento deploy:mode:set $DEPLOY_MODE
        bin/magento indexer:reindex
    else
        configure_base_url $BASEURL $USE_SECURE_URL
        bin/magento setup:upgrade
    fi

    bin/magento cache:flush

fi

# run the server

if [ "$TEST_MODE" == "true" ]; then
    echo "devcontainer built successfully and started commerce.sh and ran installation. Skipping server start."
    exit 0
fi

if [ -n "$SERVER_CMD" ]; then
    eval "$SERVER_CMD" &
fi

tail -f var/log/* &

if [ "$PHP_MODE" == "fpm" ]; then
    echo "Running in FPM mode"
    php-fpm --allow-to-run-as-root --nodaemonize
elif [ "$PHP_MODE" == "builtin" ]; then
    echo "Running in built-in server mode"
    php -S 127.0.0.1:$PORT -t ./pub/ ./phpserver/router.php
fi
