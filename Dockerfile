FROM ubuntu:zesty
MAINTAINER Jan Hermes <jan@hermes-technology.de>

# Set DEBIAN_FRONTEND to nontinteractive during build
# ARG DEBIAN_FRONTEND=noninteractive

#ENV http_proxy http://proxy-ka.iosb.fraunhofer.de:80
#ENV https_proxy http://proxy-ka.iosb.fraunhofer.de:80

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN apt-get upgrade -y

RUN apt-get install -y ruby

RUN apt-get install -y ruby-dev

RUN apt-get install -y rubygems

RUN apt-get install -y build-essential

RUN gem install jekyll

RUN gem install bundler

RUN gem install rb-inotify

WORKDIR /data
VOLUME ["/data"]
