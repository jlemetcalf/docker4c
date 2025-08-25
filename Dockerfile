#######################################
# CI image:
#   the one used by your CI server
#######################################
FROM ubuntu:24.04 AS docker4c_ci_image

ARG DEBIAN_FRONTEND=noninteractive
ARG CLANG_VERSION=18

# fix "Missing privilege separation directory":
# https://bugs.launchpad.net/ubuntu/+source/openssh/+bug/45234
RUN mkdir -p /run/sshd && \
  apt-get update && apt-get -y dist-upgrade && \
  apt-get -y install --fix-missing \
  build-essential \
  bzip2 \
  ccache \
  clang-${CLANG_VERSION} \
  clangd-${CLANG_VERSION} \
  clang-format-${CLANG_VERSION} \
  clang-tidy-${CLANG_VERSION} \
  cmake \
  cppcheck \
  curl \
  doxygen \
  gcovr \
  git \
  graphviz \
  libclang-${CLANG_VERSION}-dev \
  linux-tools-generic \
  lldb-${CLANG_VERSION} \
  lld-${CLANG_VERSION} \
  lsb-release \
  ninja-build \
  python3 \
  python3-pip \
  shellcheck \
  software-properties-common \
  ssh \
  sudo \
  tar \
  unzip \
  valgrind \
  wget && \
  \
  apt-get autoremove -y && apt-get clean && \
  \
  for c in $(ls /usr/bin/clang*-${CLANG_VERSION}); do link=$(echo $c | sed "s/-${CLANG_VERSION}//"); ln -sf $c $link; done && \
  update-alternatives --install /usr/bin/cc cc /usr/bin/clang 1000 && \
  update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 1000 

# build include-what-you-use in the version that matches CLANG_VERSION (iwyu branch name)
WORKDIR /var/tmp/build_iwyu
RUN curl -sSL https://github.com/include-what-you-use/include-what-you-use/archive/refs/heads/clang_${CLANG_VERSION}.zip -o temp.zip && \
  unzip temp.zip && rm temp.zip && mv include-what-you-use-clang_${CLANG_VERSION}/* . && rm -r include-what-you-use-clang_${CLANG_VERSION} && \
  cmake -DCMAKE_INSTALL_PREFIX=/usr -Bcmake-build && \
  cmake --build cmake-build --target install -- -j ${NCPU} && \
  ldconfig

WORKDIR /
RUN rm -rf /var/tmp/build_iwyu


#######################################
# DEV image:
#   the one you run locally
#######################################
FROM docker4c_ci_image AS docker4c_dev_image

RUN apt-get -y install --fix-missing \
  cmake-curses-gui \
  gdb \
  gdbserver \
  python-is-python3 \
  vim \
  python3.12-venv \
  && apt-get autoremove -y && apt-get clean && \
  \
  groupadd -g 2000 dev && \
  useradd -m -u 2000 -g 2000 -d /home/dev -s /bin/bash dev && \
  usermod -a -G adm,cdrom,sudo,dip,plugdev dev && \
  echo 'dev:dev' | chpasswd && \
  echo "dev   ALL=(ALL:ALL) ALL" >> /etc/sudoers

USER dev
WORKDIR /home/dev

RUN python3 -m venv venv
ENV PATH="/home/dev/venv/bin:$PATH"
RUN pip install behave conan pexpect requests
RUN echo "source /home/dev/venv/bin/activate" >> /home/dev/.bashrc

RUN sed -i 's/\\h/docker/;s/01;32m/01;33m/' /home/dev/.bashrc \
  && mkdir -p /home/dev/git
