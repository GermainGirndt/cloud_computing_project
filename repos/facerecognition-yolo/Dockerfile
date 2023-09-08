FROM ubuntu:18.04

LABEL maintainer="julian.fischer@anynines.com"
LABEL description="Facerecognition using (Darnket) Yolo Weights."

RUN mkdir /workdir

WORKDIR /workdir

ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Installation
# TODO: set a fix dependency version for Python and Ruby (e.g. python=3.10.12; ruby= )
RUN apt-get update && apt-get -y install --no-install-recommends \
  python3 python3-numpy python3-setuptools python3-pip\
  libopencv-dev opencv-data \
  pkg-config \
  apt-utils \
  autoconf \
  automake \
  libtool \
  build-essential \
  git \
  ruby-dev \
  ruby \
  libxml2-dev \
  libcurl4-openssl-dev \
  vim

# both dependencies needed for opencv-python-headless
RUN pip3 install scikit-build
RUN apt-get -y install --no-install-recommends \
  cmake \
  python3-dev
RUN pip3 install opencv-python

# changed bundler version since install was throwing incompatibility error
RUN gem install bundler -v 2.3.26

RUN ruby -v

COPY samples/bundeskanzler.jpg /workdir/object-detection-opencv/bundeskanzler.jpg
COPY yolo_opencv.py /workdir/yolo_opencv.py
COPY yolov3.cfg /workdir/yolov3.cfg
COPY yolov3.txt  /workdir/yolov3.txt 
COPY yolov3.weights /workdir/yolov3.weights



# Provides an exemplary original file for manual testing.
RUN mkdir /tmp/object_recognition
RUN cp /workdir/object-detection-opencv/bundeskanzler.jpg /tmp/object_recognition/original-image.jpg

COPY Gemfile /workdir/Gemfile
COPY worker.rb /workdir/worker.rb

RUN bundle

# Recommended CMD
# cd /workdir/ && python3 yolo_opencv.py --image /tmp/object_recognition/original-image.jpg --config yolov3.cfg --weights yolov3.weights --classes yolov3.txt 

CMD ["ruby", "worker.rb"]