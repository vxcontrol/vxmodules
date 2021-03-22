#!/bin/bash

export LANG=C.UTF-8

# Test connection to minio
while true; do
    mc config host add vxm "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" 2>&1 1>/dev/null
    if [ $? -eq 0 ]; then
        echo "connect to minio was successful"
        break
    fi
    echo "failed to connect to minio"
    sleep 1
done

mc mb --ignore-existing vxm/$MINIO_BUCKET_NAME

for dir in $(ls -d *); do
    mc rm --recursive --force vxm/$MINIO_BUCKET_NAME/${dir}
done
mc cp --recursive /opt/vxmodules/mon/ vxm/$MINIO_BUCKET_NAME


# Test connection to mysql
while true; do
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e ";" 2>&1 1>/dev/null
    if [ $? -eq 0 ]; then
        echo "connect to mysql was successful"
        break
    fi
    echo "failed to connect to mysql"
    sleep 1
done

# Waitign migrations from vxui into mysql
while true; do
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT id FROM modules;" 2>&1 1>/dev/null
    if [ $? -eq 0 ]; then
        echo "vxui migrations was found"
        break
    fi
    echo "failed to update modules table"
    sleep 1
done


mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "ALTER DATABASE \`${DB_NAME}\` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci;"
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /opt/vxmodules/dump.sql


# Make new vx service if it needs
if [ ! -z "$NEW_SERVICE" ]; then
    echo "creating service"

    get_ns_option() {
        echo "${NEW_SERVICE}" | jq -r "$1"
    }

    NS_DB_HOST=$( get_ns_option .db.host )
    NS_DB_PORT=$( get_ns_option .db.port )
    NS_DB_NAME=$( get_ns_option .db.name )
    NS_DB_USER=$( get_ns_option .db.user )
    NS_DB_PASS=$( get_ns_option .db.pass )

    NS_S3_ENDPOINT=$( get_ns_option .s3.endpoint )
    NS_S3_ACCESS_KEY=$( get_ns_option .s3.access_key )
    NS_S3_SECRET_KEY=$( get_ns_option .s3.secret_key )
    NS_S3_BUCKET_NAME=$( get_ns_option .s3.bucket_name )

    # Creating new minio user
    cat <<EOT >> /opt/vxmodules/minio_new_user.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${NS_S3_BUCKET_NAME}/*"
      ],
      "Sid": ""
    }
  ]
}
EOT
    mc config host add vxinst "$NS_S3_ENDPOINT" "$NS_S3_ACCESS_KEY" "$NS_S3_SECRET_KEY" 2>&1 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "creating new servive S3 bucket and user"
        mc admin policy add vxm ${NS_S3_BUCKET_NAME} /opt/vxmodules/minio_new_user.json
        mc admin user add vxm ${NS_S3_ACCESS_KEY} ${NS_S3_SECRET_KEY}
        mc admin policy set vxm ${NS_S3_BUCKET_NAME} user=${NS_S3_ACCESS_KEY}
        mc config host add vxinst "$NS_S3_ENDPOINT" "$NS_S3_ACCESS_KEY" "$NS_S3_SECRET_KEY"

        mc mb --ignore-existing vxm/$NS_S3_BUCKET_NAME

        # To prevent error on starting vxserver
        touch /tmp/dummy
        mc cp /tmp/dummy vxinst/${NS_S3_BUCKET_NAME}/utils/
    else
        echo "servive S3 bucket and user already exists"
    fi

    cat <<EOT >> /opt/vxmodules/new_db.sql
CREATE DATABASE \`${NS_DB_NAME}\`;
CREATE USER '${NS_DB_USER}'@'%' IDENTIFIED BY '${NS_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${NS_DB_NAME}\`.* TO '${NS_DB_USER}'@'%';
ALTER DATABASE \`${NS_DB_NAME}\` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci;
EOT
    cat <<EOT >> /opt/vxmodules/new_service.sql
INSERT IGNORE INTO \`tenants\` (\`id\`, \`status\`) VALUES (1, 'active');
INSERT IGNORE INTO \`services\` (\`id\`, \`tenant_id\`, \`name\`, \`type\`, \`status\`, \`info\`) VALUES (1, 1, 'First server', 'vxmonitor', 'active', '${NEW_SERVICE}');
EOT

    # Create new user and DB
    mysql -h"$NS_DB_HOST" -P"$NS_DB_PORT" -u"$NS_DB_USER" -p"$NS_DB_PASS" -e ";" "$NS_DB_NAME" 2>&1 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "creating new servive DB and user"
        mysql -h"$NS_DB_HOST" -P"$NS_DB_PORT" -u"$DB_ROOT_USER" -p"$DB_ROOT_PASS" -f < /opt/vxmodules/new_db.sql
    else
        echo "service DB and user already exists"
    fi

    # Register new service into Global DB
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /opt/vxmodules/new_service.sql

    echo "creating service complete"
fi


# Make new vx service if it needs
if [ ! -z "$NEW_UI_USER" ]; then
    echo "creating user"

    get_nu_option() {
        echo "${NEW_UI_USER}" | jq -r "$1"
    }

    NU_DB_MAIL=$( get_nu_option .mail )
    NU_DB_NAME=$( get_nu_option .name )
    NU_DB_PASS=$( get_nu_option .pass )

    cat <<EOT >> /opt/vxmodules/new_ui_user.sql
INSERT IGNORE INTO \`users\` (\`id\`, \`status\`, \`group_id\`, \`tenant_id\`, \`mail\`, \`name\`, \`password\`) VALUES (1, 'active', 1, 1, '${NU_DB_MAIL}', '${NU_DB_NAME}', '${NU_DB_PASS}');
EOT

    # Register new UI user into Global DB
    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /opt/vxmodules/new_ui_user.sql

    echo "creating service complete"
fi

echo "done"

sleep infinity
