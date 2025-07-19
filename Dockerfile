FROM python:3-alpine3.22

EXPOSE 15740/tcp
EXPOSE 15740/udp
EXPOSE 1900/udp

ENV PTP_GUID="ff:ff:52:54:00:b6:fd:a9:ff:ff:52:3c:28:07:a9:3a"

ENV PUID=1000
ENV PGID=1000

ENV GPHOTO_ARGS=--get-all-files,--skip-existing
ENV SAVE_TO_DATE_FOLDERS=false

ENV DEBUG=false

WORKDIR /root

ADD make_gphoto_settings.sh .
ADD gphoto_connect_test.sh .
ADD make_libgphoto2.sh .
ADD sony-library_c.patch .

RUN chmod +x make_gphoto_settings.sh
RUN chmod +x gphoto_connect_test.sh
RUN chmod +x make_libgphoto2.sh

RUN apk add --no-cache gphoto2 exiftool build-base libexif-dev libusb-dev libjpeg-turbo-dev libtool autoconf pkgconfig automake patch gettext-dev git && \
    /root/make_libgphoto2.sh && \
    apk del build-base libexif-dev libusb-dev libjpeg-turbo-dev libtool autoconf pkgconfig automake patch gettext-dev git && \
    rm -rf /var/cache/apk/* && \
    rm -rf /root/make_libgphoto2.sh && \
    rm -rf /root/sony-library_c.patch && \
    rm -rf /root/v2.5.31.tar.gz && \
    rm -rf /root/temp
RUN pip install --no-cache requests

ADD sony-pm-alt.py .

VOLUME /var/lib/Sony

CMD /root/make_gphoto_settings.sh && exec python3 sony-pm-alt.py
