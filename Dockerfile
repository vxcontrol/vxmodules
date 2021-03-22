FROM minio/mc

FROM mysql

COPY --from=0 /usr/bin/mc /usr/bin/mc

# Directory for Monitor service modules
RUN mkdir -p /opt/vxmodules/mon

# Entrypoint script
COPY startup.sh /opt/vxmodules/
# SQL file generator script
COPY gen_sql.sh /opt/vxmodules/
# Content for test loading modules from S3
COPY generic /opt/vxmodules/mon/generic
COPY lua-interpreter /opt/vxmodules/mon/lua-interpreter
COPY pam /opt/vxmodules/mon/pam
COPY test /opt/vxmodules/mon/test
COPY utils /opt/vxmodules/mon/utils
COPY config.json /opt/vxmodules/mon/

RUN chmod +x /opt/vxmodules/startup.sh
RUN chmod +x /opt/vxmodules/gen_sql.sh

RUN \
  apt update && \
  apt install -y ca-certificates && \
  apt install -y jq && \
  apt clean -y && \
  apt autoremove -y && \
  rm -rf /tmp/* /var/tmp/* && \
  rm -rf /var/lib/apt/lists/* && \
  echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

WORKDIR /opt/vxmodules/mon/

# Generate new dump.sql
RUN /opt/vxmodules/gen_sql.sh ../dump.sql

ENTRYPOINT ["/opt/vxmodules/startup.sh"]
