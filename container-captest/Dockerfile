FROM fedora:32

COPY create-tests.sh /opt/captest/bin/create-tests.sh
COPY create-demo.sh /opt/captest/bin/create-demo.sh
COPY test-capabilities.sh /opt/captest/bin/test-capabilities.sh
COPY README.testing_with_netcat /opt/captest/README.testing_with_netcat

RUN \
  dnf -y install libcap-ng-utils nmap-ncat && \
  useradd -m -U -s /bin/bash -u 1001 captest && \
  mkdir -p /opt/captest/tests /opt/captest/bin && \
  chown -R captest:captest /opt/captest && \
  chmod -R 0777 /opt/captest && \
  /opt/captest/bin/create-tests.sh && \
  /opt/captest/bin/create-demo.sh && \
  dnf clean all && rm -rf /var/cache/dnf/*

USER 1001
CMD /opt/captest/bin/test-capabilities.sh
