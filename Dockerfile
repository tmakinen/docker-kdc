FROM docker.io/rockylinux/rockylinux:10.2.20260525.0

COPY requirements.txt /usr/local/src

RUN set -eux ; \
    dnf -y upgrade ; \
    dnf -y install --nodocs --setopt=install_weak_deps=False \
        epel-release ; \
    dnf -y install --nodocs --setopt=install_weak_deps=False \
        krb5-server \
        krb5-server-ldap \
        python3-pip \
        supervisor ; \
    dnf -y clean all ; \
    rm -rf /var/cache/dnf /var/log/dnf.* ; \
    pip3 install --root-user-action=ignore -r /usr/local/src/requirements.txt ; \
    rm -f /usr/local/src/requirements.txt

RUN set -eux ; \
    useradd -c "KDCProxy" -d /var/empty -M -r -s /sbin/nologin kdcproxy

COPY entrypoint.sh /entrypoint.sh

RUN set -eux ; \
    { \
        echo "[supervisord]" ; \
        echo "user = root" ; \
        echo "nodaemon = true" ; \
        echo "directory = /var/empty" ; \
        echo "logfile = /dev/null" ; \
        echo "logfile_maxbytes = 0" ; \
        echo "loglevel = info" ; \
        echo "pidfile = /dev/null" ; \
        echo ; \
        echo "[include]" ; \
        echo "files = supervisord.d/*.ini" ; \
    } | tee /etc/supervisord.conf ; \
    { \
        echo "[program:kdcproxy]" ; \
        echo "command = /usr/local/bin/gunicorn --bind :8000 -w 4 kdcproxy" ; \
        echo "user = kdcproxy" ; \
        echo "environment = TMPDIR=/run/kdcproxy" ; \
        echo "redirect_stderr = true" ; \
        echo "stdout_logfile = /dev/stdout" ; \
        echo "stdout_logfile_maxbytes = 0" ; \
    } | tee /etc/supervisord.d/kdcproxy.ini ; \
    { \
        echo "[program:krb5kdc]" ; \
        echo "command = /usr/sbin/krb5kdc -n -w 4" ; \
        echo "redirect_stderr = true" ; \
        echo "stdout_logfile = /dev/stdout" ; \
        echo "stdout_logfile_maxbytes = 0" ; \
    } | tee /etc/supervisord.d/krb5kdc.ini

EXPOSE 8000/tcp

WORKDIR "/run"
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
