FROM ubuntu:22.04

RUN apt update
RUN apt install -y python3 nodejs python3-pip
RUN pip3 install https://github.com/mikf/gallery-dl/archive/master.zip

RUN mkdir server && mkdir public
COPY vms-server/* ./server
RUN rm server/user.db
COPY vms-web/build/* ./public

WORKDIR /server
ENTRYPOINT [ "node", "app.js" ]