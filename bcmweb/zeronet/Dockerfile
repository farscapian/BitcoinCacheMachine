ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ENV ENABLE_TOR true

# this command ENABLES the multiuser plugin https://zeronet.io/docs/faq/
RUN mv /root/plugins/disabled-Multiuser /root/plugins/Multiuser

CMD (! ${ENABLE_TOR} || tor&) && python3 zeronet.py --ui_ip 0.0.0.0 --fileserver_port 26552 --tor always
